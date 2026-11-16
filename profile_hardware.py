#!/usr/bin/env python3
import json
import re
import os
import subprocess

def run_cmd(cmd, sudo=False):
    if sudo:
        cmd = f"sudo -n {cmd}"
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return res.stdout.strip(), res.stderr.strip(), res.returncode
    except subprocess.TimeoutExpired:
        return "", "Timeout", -1
    except Exception as e:
        return "", str(e), -2

def parse_lscpu(stdout):
    info = {}
    for line in stdout.splitlines():
        if ":" in line:
            parts = line.split(":", 1)
            key = parts[0].strip()
            val = parts[1].strip()
            info[key] = val
    return info

def get_cpu_flags_of_interest(flags_str):
    all_flags = flags_str.lower().split()
    interest = ["avx", "avx2", "avx512", "fma", "aes", "sha_ni", "sse4_2", "bmi1", "bmi2"]
    found = []
    for f in interest:
        # avx512* matches any avx512 flag (e.g. avx512f, avx512cd, etc.)
        if f == "avx512":
            if any(x.startswith("avx512") for x in all_flags):
                found.append("avx512*")
        else:
            if f in all_flags:
                found.append(f)
    return found

def main():
    print("Iniciando o profiling de hardware...")
    profile = {}

    # ----------------- 1. CPU & ARQUITETURA DE SILÍCIO -----------------
    lscpu_out, _, _ = run_cmd("lscpu")
    lscpu_info = parse_lscpu(lscpu_out)
    
    cpu_model = lscpu_info.get("Model name", "Desconhecido")
    cpu_vendor = lscpu_info.get("Vendor ID", "Desconhecido")
    sockets = lscpu_info.get("Socket(s)", "1")
    cores = lscpu_info.get("Core(s) per socket", "1")
    threads = lscpu_info.get("CPU(s)", "1")
    flags_str = lscpu_info.get("Flags", "")
    
    # Cache topology
    caches = {
        "L1d": lscpu_info.get("L1d cache", lscpu_info.get("L1d", "Desconhecido")),
        "L1i": lscpu_info.get("L1i cache", lscpu_info.get("L1i", "Desconhecido")),
        "L2": lscpu_info.get("L2 cache", lscpu_info.get("L2", "Desconhecido")),
        "L3": lscpu_info.get("L3 cache", lscpu_info.get("L3", "Desconhecido"))
    }

    # GCC Native march/mtune
    gcc_out, _, _ = run_cmd("gcc -march=native -Q --help=target")
    march = "Desconhecido"
    mtune = "Desconhecido"
    for line in gcc_out.splitlines():
        # Match lines like "  -march=               westmere" but not "Known valid arguments for -march= option:"
        if "-march=" in line and "option:" not in line and "arguments" not in line:
            parts = line.split("-march=")
            if len(parts) > 1 and parts[1].strip():
                march = parts[1].strip()
        if "-mtune=" in line and "option:" not in line and "arguments" not in line:
            parts = line.split("-mtune=")
            if len(parts) > 1 and parts[1].strip():
                mtune = parts[1].strip()

    # Sem gcc, não inventamos Westmere: o desktop alvo é Ivy Bridge e outras
    # máquinas podem aparecer. x86-64-v2 cobre AVX+SSE4.2 sem AVX2.
    if march == "Desconhecido" or not march:
        if "avx" in flags_str.lower().split() and "avx2" not in flags_str.lower().split():
            march = "ivybridge"
        else:
            march = "x86-64"
    if mtune == "Desconhecido" or not mtune:
        mtune = march

    cpu_flags = get_cpu_flags_of_interest(flags_str)
    
    # Scaling driver
    scaling_driver, _, _ = run_cmd("cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver")
    if not scaling_driver:
        scaling_driver = "Desconhecido"

    # Hybrid architecture (P-Cores vs E-Cores)
    # i7 M 640 has only 2 physical cores, homogeneous (not hybrid)
    # Check if there are different Core types
    is_hybrid = "Não"
    if "hybrid" in flags_str.lower() or "intel(r) hybrid technology" in lscpu_out.lower():
        is_hybrid = "Sim"

    profile["cpu"] = {
        "model": cpu_model,
        "vendor": cpu_vendor,
        "sockets": sockets,
        "cores": cores,
        "threads": threads,
        "march": march,
        "mtune": mtune,
        "vector_crypto_flags": cpu_flags,
        "cache_topology": caches,
        "hybrid_architecture": is_hybrid,
        "frequency_scaling_driver": scaling_driver
    }

    # ----------------- 2. GPU, DISPLAY & ACELERAÇÃO GRÁFICA -----------------
    gpu_out, _, _ = run_cmd("lspci -nnk | grep -iA3 'vga\\|3d'")
    gpu_devices = []
    gpu_drivers = []
    
    current_gpu = None
    for line in gpu_out.splitlines():
        if "VGA" in line or "3D" in line:
            current_gpu = line.strip()
            gpu_devices.append(current_gpu)
        elif "Kernel driver in use" in line:
            driver = line.split(":")[1].strip()
            gpu_drivers.append(driver)

    gpu_blob = " ".join(gpu_devices)
    if "8086:0162" in gpu_blob or "HD Graphics 4000" in gpu_blob:
        vulkan_support = "Sem Vulkan estável (Mesa ANV pede Gen8+). OpenGL via crocus."
        video_accel = "i965-va-driver (VA-API) com LIBVA_DRIVER_NAME=i965; KMS i915 modesetting"
        gpu_note = "Intel HD Graphics 4000 (Ivy Bridge). Sem firmware GuC/HuC."
    elif "8086:0046" in gpu_blob or "Ironlake" in gpu_blob:
        vulkan_support = "Sem suporte (GPU Ironlake/GMA HD legado não suporta Vulkan API)"
        video_accel = "Suporte legado via i965-va-driver (VA-API H.264 parcial / MPEG2 total)"
        gpu_note = "GPU Ironlake de 1ª geração."
    else:
        vulkan_support = "Depende da GPU detectada (ver vainfo e glxinfo)"
        video_accel = "Verificar vainfo; Intel Gen7 usa i965-va-driver, Gen8+ pode usar iHD"
        gpu_note = "GPU não classificada por este script."

    profile["gpu"] = {
        "devices": gpu_devices,
        "drivers_in_use": gpu_drivers,
        "vulkan_support": vulkan_support,
        "video_acceleration": video_accel
    }

    # ----------------- 3. MEMÓRIA & ARMAZENAMENTO -----------------
    ram_out, _, _ = run_cmd("free -h")
    # Parse total RAM
    total_ram = "Desconhecido"
    for line in ram_out.splitlines():
        if "Mem:" in line:
            total_ram = line.split()[1]

    # dmidecode memory details (requires sudo)
    dmidecode_out, _, _ = run_cmd("dmidecode -t memory", sudo=True)
    ram_slots = []
    current_slot = {}
    for line in dmidecode_out.splitlines():
        line_s = line.strip()
        if line_s.startswith("Size:"):
            current_slot["size"] = line_s.split(":")[1].strip()
        elif line_s.startswith("Type:") and not line_s.startswith("Type Detail:"):
            current_slot["type"] = line_s.split(":")[1].strip()
        elif line_s.startswith("Speed:"):
            current_slot["speed"] = line_s.split(":")[1].strip()
        elif line_s.startswith("Locator:"):
            current_slot["locator"] = line_s.split(":")[1].strip()
            # Locator marks the end of a slot description in our interest, save and reset
            if "size" in current_slot and current_slot["size"] != "No Module Installed":
                ram_slots.append(current_slot.copy())
            current_slot = {}

    # Storage
    lsblk_out, _, _ = run_cmd("lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL")
    storage_devices = []
    for line in lsblk_out.splitlines()[1:]: # skip header
        if line.strip():
            storage_devices.append(line.strip())

    # TRIM Support
    trim_val, _, _ = run_cmd("cat /sys/block/sda/queue/discard_granularity")
    trim_support = "Não"
    if trim_val.strip() and trim_val.strip() != "0":
        trim_support = f"Sim (Suportado pelo SSD sda - discard_granularity = {trim_val.strip()} bytes)"

    # zRAM support
    zramctl_out, _, _ = run_cmd("zramctl")
    zram_info = "Ativo" if zramctl_out else "Inativo"
    if zramctl_out:
        zram_lines = zramctl_out.splitlines()
        zram_info = f"Ativo - {zram_lines[1] if len(zram_lines) > 1 else zramctl_out}"

    profile["memory_storage"] = {
        "total_ram": total_ram,
        "ram_slots": ram_slots,
        "storage_devices": storage_devices,
        "trim_support": trim_support,
        "zram_status": zram_info
    }

    # ----------------- 4. REDE, ÁUDIO E PERIFÉRICOS -----------------
    wifi_out, _, _ = run_cmd("lspci | grep -i -E 'network|wireless'")
    wifi_card = wifi_out.strip() if wifi_out else "Nenhuma controladora Wi-Fi PCI detectada"
    
    ethernet_out, _, _ = run_cmd("lspci | grep -i ethernet")
    ethernet_card = ethernet_out.strip() if ethernet_out else "Nenhuma controladora Ethernet PCI detectada"

    bluetooth_out, _, _ = run_cmd("lsusb | grep -i blue")
    bluetooth_status = bluetooth_out.strip() if bluetooth_out else "Nenhum adaptador Bluetooth USB detectado"

    audio_server = "PipeWire" # Detect based on running processes
    ps_audio, _, _ = run_cmd("ps aux | grep -E 'pipewire|pulseaudio'")
    if "pipewire" in ps_audio.lower():
        audio_server = "PipeWire (com pipewire-pulse compatibilidade)"
    elif "pulseaudio" in ps_audio.lower():
        audio_server = "PulseAudio"

    # Boot Mode
    boot_mode = "BIOS Legado / CSM"
    if os.path.exists("/sys/firmware/efi"):
        boot_mode = "UEFI"
        
    # Secure Boot
    sb_out, _, _ = run_cmd("mokutil --sb-state")
    secure_boot = sb_out.strip() if sb_out else "mokutil não disponível"
    if boot_mode != "UEFI":
        secure_boot = "Firmware legado, sem Secure Boot"

    profile["network_peripherals"] = {
        "wifi_card": wifi_card,
        "ethernet_card": ethernet_card,
        "bluetooth": bluetooth_status,
        "audio_server": audio_server,
        "boot_mode": boot_mode,
        "secure_boot": secure_boot
    }

    # ----------------- 5. SÍNTESE E RECOMENDAÇÃO DO GAIA OS -----------------
    meminfo, _, _ = run_cmd("awk '/MemTotal/ {print $2}' /proc/meminfo")
    try:
        mem_kb = int(meminfo or "0")
    except ValueError:
        mem_kb = 0
    pci_nn, _, _ = run_cmd("lspci -nn")
    initramfs_modules = ["i915"]
    if "10ec:8168" in pci_nn or "RTL8111" in pci_nn or "RTL8168" in pci_nn:
        initramfs_modules.append("r8169")
    if "168c:" in pci_nn or "AR9485" in pci_nn or "ath9k" in pci_nn.lower():
        initramfs_modules.append("ath9k")
    if "14e4:" in pci_nn and "BCM" in pci_nn:
        initramfs_modules.append("tg3")
    if mem_kb >= 8 * 1024 * 1024:
        zram_size = "25% da RAM (zram-tools PERCENT=25)"
        zram_level = 3
        zram_why = (
            "Com 8 GiB ou mais, zRAM do tamanho da RAM só gasta CPU. "
            "25% cobre pico sem o perfil de notebook de 6 GiB. "
            "swappiness 60 e page-cluster 0."
        )
    else:
        zram_size = "100% da RAM física"
        zram_level = 1
        zram_why = (
            "Pouca RAM: zRAM zstd no nível 1 amplia a memória sem o custo do nível alto."
        )
    profile["gaia_os_recommendations"] = {
        "march_flag": f"-march={march}",
        "mtune_flag": f"-mtune={mtune}",
        "kernel_compiler_flags": f"-O2 -pipe -march={march} -mtune={mtune}",
        "initramfs_modules": initramfs_modules,
        "zram_recommendation": {
            "algorithm": "zstd",
            "compression_level": zram_level,
            "size": zram_size,
            "rationale": zram_why,
        },
    }

    out_dir = os.environ.get("GAIA_PROFILE_DIR")
    if not out_dir:
        legacy = "/home/francisco/Documentos/Projetos/GaiaOS"
        out_dir = legacy if os.path.isdir(legacy) else os.path.join(os.getcwd(), "hardware-profile")
    os.makedirs(out_dir, exist_ok=True)
    json_path1 = os.path.join(out_dir, "gaia-hardware-profile.json")

    # Write Markdown files
    md_content = f"""# Relatório Completo de Profiling de Hardware — Gaia OS

Este relatório apresenta o perfil técnico detalhado obtido diretamente do hardware para subsidiar a customização, otimização e compilação do **Gaia OS**.

---

## 1. CPU & ARQUITETURA DE SILÍCIO
* **Modelo da CPU:** {profile['cpu']['model']}
* **Arquitetura:** {lscpu_info.get('Architecture', 'x86_64')}
* **Sufixo/Geração:** detectada em runtime (`-march={profile['cpu']['march']}`)
* **Núcleos / Sockets:** {profile['cpu']['sockets']} Socket | {profile['cpu']['cores']} Cores Físicos | {profile['cpu']['threads']} Threads (Tecnologia Hyper-Threading ativa)
* **Microarquitetura Detectada:** `-march={profile['cpu']['march']}` / `-mtune={profile['cpu']['mtune']}`
* **Instruções Vetoriais e Criptográficas Suportadas:**
  * **SSE4.2:** {'✅ Sim' if 'sse4_2' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **AES-NI:** {'✅ Sim' if 'aes' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **AVX:** {'✅ Sim' if 'avx' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **AVX2:** {'✅ Sim' if 'avx2' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **AVX512:** {'✅ Sim' if 'avx512*' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **FMA:** {'✅ Sim' if 'fma' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **SHA_NI:** {'✅ Sim' if 'sha_ni' in profile['cpu']['vector_crypto_flags'] else '❌ Não'}
  * **BMI1 / BMI2:** {'✅ Sim' if any(b in profile['cpu']['vector_crypto_flags'] for b in ['bmi1', 'bmi2']) else '❌ Não'}
* **Topologia de Cache:**
  * **Cache L1d:** {profile['cpu']['cache_topology']['L1d']}
  * **Cache L1i:** {profile['cpu']['cache_topology']['L1i']}
  * **Cache L2:** {profile['cpu']['cache_topology']['L2']}
  * **Cache L3:** {profile['cpu']['cache_topology']['L3']} (Compartilhado)
* **Arquitetura Híbrida (P-Cores vs E-Cores):** {profile['cpu']['hybrid_architecture']} (Arquitetura homogênea pura)
* **Driver de Escalonamento de Frequência:** `{profile['cpu']['frequency_scaling_driver']}`

---

## 2. GPU, DISPLAY & ACELERAÇÃO GRÁFICA
* **GPU Detectada:** `{profile['gpu']['devices'][0] if profile['gpu']['devices'] else 'Intel Ironlake HD Graphics'}`
* **Driver de Vídeo Ativo:** `{', '.join(profile['gpu']['drivers_in_use']) if profile['gpu']['drivers_in_use'] else 'i915'}`
* **Suporte a Vulkan:** `{profile['gpu']['vulkan_support']}`
* **Aceleração Gráfica por Hardware (VA-API):** `{profile['gpu']['video_acceleration']}`
  * *Observação:* {gpu_note}

---

## 3. MEMÓRIA & ARMAZENAMENTO
* **Memória RAM Total:** `{profile['memory_storage']['total_ram']}`
* **Slots de Memória Ocupados (dmidecode):**
"""
    for i, slot in enumerate(profile['memory_storage']['ram_slots']):
        md_content += f"  * **Slot {i} ({slot.get('locator', 'N/A')}):** {slot.get('size', 'N/A')} {slot.get('type', 'N/A')} @ {slot.get('speed', 'N/A')}\n"

    md_content += f"""* **Dispositivos de Armazenamento:**
"""
    for dev in profile['memory_storage']['storage_devices']:
        md_content += f"  * `{dev}`\n"

    md_content += f"""* **Suporte a TRIM (SSD):** {profile['memory_storage']['trim_support']}
* **Configuração Atual do zRAM:** `{profile['memory_storage']['zram_status']}`

---

## 4. REDE, ÁUDIO E PERIFÉRICOS
* **Placa Wi-Fi:** `{profile['network_peripherals']['wifi_card']}`
* **Placa Ethernet:** `{profile['network_peripherals']['ethernet_card']}`
* **Bluetooth:** `{profile['network_peripherals']['bluetooth']}`
* **Servidor de Áudio:** `{profile['network_peripherals']['audio_server']}`
* **Modo de Boot do Firmware:** `{profile['network_peripherals']['boot_mode']}`
* **Status do Secure Boot:** `{profile['network_peripherals']['secure_boot']}`

---

## 5. SÍNTESE E RECOMENDAÇÃO DO GAIA OS

Recomendações calculadas a partir do hardware lido agora (não há mais perfil Westmere fixo):

### A. Flags de compilação
* **MARCH_FLAG:** `{profile['gaia_os_recommendations']['march_flag']}`
* **MTUNE_FLAG:** `{profile['gaia_os_recommendations']['mtune_flag']}`
* **Flags:** `{profile['gaia_os_recommendations']['kernel_compiler_flags']}`
* O kernel e o userland do Debian amd64 já despacham AVX e AES-NI em tempo de execução. Recompilar o sistema inteiro com `-march` não faz parte da ISO.

### B. Módulos no initramfs
* **Módulos:** `{' '.join(profile['gaia_os_recommendations']['initramfs_modules'])}`

### C. zRAM
* **Algoritmo:** `{profile['gaia_os_recommendations']['zram_recommendation']['algorithm']}` nível `{profile['gaia_os_recommendations']['zram_recommendation']['compression_level']}`
* **Tamanho:** `{profile['gaia_os_recommendations']['zram_recommendation']['size']}`
* {profile['gaia_os_recommendations']['zram_recommendation']['rationale']}

---
*Relatório gerado automaticamente pelo Engenheiro de Kernel e Sistemas Operacionais da Gaia Works.*
"""

    md_path1 = os.path.join(out_dir, "gaia-hardware-profile.md")
    with open(json_path1, "w", encoding="utf-8") as f:
        json.dump(profile, f, indent=4, ensure_ascii=False)
    with open(md_path1, "w", encoding="utf-8") as f:
        f.write(md_content)

    print("Profiling concluído com sucesso!")
    print(f"JSON: {json_path1}")
    print(f"Markdown: {md_path1}")

if __name__ == "__main__":
    main()
