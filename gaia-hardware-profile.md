# Perfil de hardware — Gaia OS Ivy Bridge Edition

Perfil-alvo do desktop do Francisco. Não é uma leitura feita na máquina de build da ISO. Para gerar um relatório da máquina em que o script roda, use `profile_hardware.py` (ele grava em `./hardware-profile/` ou em `GAIA_PROFILE_DIR`).

## 1. CPU

* **Modelo:** Intel Core i7-3770 @ 3.40 GHz (Ivy Bridge, 22 nm)
* **Núcleos:** 1 soquete, 4 núcleos, 8 threads, VT-x
* **Microcódigo na BIOS hoje:** 0x21 — o pacote `intel-microcode` do Trixie carrega a revisão mais nova no initramfs
* **Flags úteis:** AVX, AES-NI, SSE4.2, RDRAND. Não tem AVX2, FMA, BMI nem SHA-NI
* **`-march` / `-mtune`:** `ivybridge` para software compilado na mão. O kernel e o userland do Debian amd64 já escolhem AVX e AES-NI em tempo de execução
* **Frequência:** `intel_pstate`, preferência `balance_performance`
* **Cache:** L1 32 KiB de dados e 32 KiB de instrução por núcleo, L2 256 KiB por núcleo, L3 8 MiB

## 2. Placa e firmware

* **Chipset:** Intel B75 / Panther Point
* **Firmware:** AMI UEFI 4.6.5, boot UEFI nativo, disco GPT
* **Bootloader:** `grub-efi-amd64`

## 3. Vídeo

* **GPU:** Intel HD Graphics 4000 `[8086:0162]`, driver `i915`, saída HDMI-A-1 (VGA sem uso)
* **Sessão:** modesetting. Não instalamos `xserver-xorg-video-intel`
* **OpenGL:** Mesa `crocus` (o iris é Gen8+)
* **VA-API:** `i965-va-driver`, variável `LIBVA_DRIVER_NAME=i965`
* **Vulkan:** sem suporte estável. O ANV do Mesa pede Broadwell ou mais novo
* **Firmware de GPU:** Ivy Bridge não usa GuC/HuC. `enable_guc=0`

## 4. Memória e disco

* **RAM:** 16 GiB DDR3-1600 em dois canais. A placa aceita até 32 GiB
* **zRAM:** zstd, 25% da RAM (cerca de 4 GiB), swappiness 60, `vm.page-cluster=0`. O MGLRU continua ligado (`0x0007`, TTL 1000 ms) para proteger o working set do Plasma, não porque falte RAM
* **Disco:** SSD SATA 256 GB JIEDIAN S3010-25A, TRIM, controlador AHCI Intel 7 Series `[8086:1e02]`
* **Layout que o instalador propõe:** `sda1` EFI vfat 600 MiB, `sda2` `/boot` ext4 1 GiB, `sda3` `/` ext4 com `discard`. Sem swap em disco

## 5. Rede, áudio e USB

* **Ethernet:** Realtek RTL8111/8168 `[10ec:8168]` revisão 15, módulo `r8169`, firmware `rtl_nic/rtl8168h-2.fw` (`firmware-realtek`)
* **Wi-Fi e Bluetooth:** não existem nesta máquina
* **Áudio:** Intel HDA `[8086:1e20]`, `snd_hda_intel`, codec Realtek ALC887-VD, saída analógica e HDMI. Servidor PipeWire
* **USB:** xHCI `[8086:1e31]`, EHCI `[8086:1e26]` e `[8086:1e2d]`. Receptor Lenovo Essential `[1a81:1026]` (teclado e mouse sem fio) entra como HID
* **SMBus:** `i2c_i801`

## 6. Módulos de boot

`i915`, `r8169`, `snd_hda_intel`, `ahci`, `xhci_hcd`, `ehci_pci`, `i2c_i801`. Os dois primeiros vão no initramfs para o KMS e a rede subirem cedo. AHCI e xHCI costumam já estar embutidos no kernel Debian.
