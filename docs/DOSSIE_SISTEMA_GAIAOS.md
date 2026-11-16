# Dossiê Técnico e Arquitetura do Gaia OS

> **Edição atual:** Gaia OS Ivy Bridge Edition 1.0  
> **Base:** Debian GNU/Linux 13 (Trixie), com `trixie-security`, `trixie-updates` e `trixie-backports` (prioridade 100)  
> **Máquina alvo:** desktop Intel Core i7-3770 (Ivy Bridge, 4C/8T), chipset B75, 16 GiB DDR3-1600, Intel HD Graphics 4000, Realtek RTL8111/8168, SSD SATA 256 GB, UEFI  
> **Kernel:** metapacote `linux-image-amd64` da série 6.12 LTS (a versão exata fica em `/etc/gaiaos/build-versions.txt` da ISO)  
> **Interface:** KDE Plasma 6.3 (Wayland por padrão, X11 em `plasmax11`), SDDM, Breeze Dark  
> **Instalação:** [`INSTALACAO_IVYBRIDGE.md`](INSTALACAO_IVYBRIDGE.md)  
> **Data:** 16 de Novembro de 2026  

O restante deste dossiê conserva o histórico da **edição Westmere** (Gateway NV55C, Debian 12, Plasma 5.27.5, kernel 6.1). Os escudos de CVE-2026-98432, Node2Shell e PHP2Shell continuam iguais. O que mudou para o desktop está na seção abaixo e no README.

## 0. O que a edição Ivy Bridge reavaliou

| Peça Westmere | No desktop i7-3770 |
| :--- | :--- |
| zRAM de 6 GiB (100% da RAM) e `vm.swappiness=150` | zRAM zstd de **25%** (~4 GiB em 16 GiB) e swappiness **60**. `page-cluster=0` permanece. |
| Alerta térmico aos 82 °C (CPU móvel) | Alerta aos **90 °C**. O TJMax do i7-3770 é 105 °C; 80 °C sob carga é normal num desktop. |
| `acpi-cpufreq`, sem AVX | `intel_pstate` em `balance_performance`. AVX e AES-NI existem; o Debian amd64 já os usa em tempo de execução. Não recompilamos o userland com `-march=ivybridge`. |
| initramfs `i915 ath9k tg3` | `i915` e `r8169`. Não há Wi-Fi nem Bluetooth. |
| `ModemManager` e `fwupd` mascarados | `ModemManager` mascarado (não há modem). **fwupd não é mascarado**: a placa é UEFI, mas a BIOS AMI 4.6.5 da B75 provavelmente não está no LVFS. |
| Chrome com descarte agressivo de abas (`MemorySaverModeSavings: 2`) | Valor **1** (moderado). 16 GiB não precisam do perfil de 6 GiB. |
| Plasma 5.27.5 / Qt5 no desktop | Plasma **6.3.6** / Qt 6. A interface do Guardian passou para PyQt6 para não puxar o Qt5 inteiro. |
| BIOS legado | UEFI nativo, GRUB `grub-efi-amd64`, tabela GPT, EFI de 600 MiB, `/boot` de 1 GiB, raiz ext4 com TRIM. |
| Sem canal de atualização de rede | APT de segurança todo dia (`unattended-upgrades`) e `gaia-update.timer` semanal, com snapshot antes. |

---

## Histórico — edição Westmere (Gateway NV55C)

> **Distribuição daquela máquina:** Debian GNU/Linux 12 Bookworm  
> **Plataforma:** Gateway NV55C — Intel Core i7 M 640 @ 2.80GHz (Westmere/Arrandale, 2C/4T)  
> **Kernel daquela máquina:** Linux `6.1.0-55-amd64` (`6.1.192-1`, 2026-11-14)  
> **Memória:** 5.5 GiB DDR3 + 6.0 GiB zRAM  
> **Interface daquela época:** KDE Plasma `5.27.5` / SDDM `0.19.0-5`  

---

## 1. Visão Geral e Filosofia do Sistema

O **Gaia OS** nasceu da necessidade de transformar um notebook legado (Gateway NV55C com processador Intel Core i7 de 1ª Geração) em uma estação de trabalho e gateway de desenvolvimento moderna, ultra-responsiva, segura e autossuficiente.

Diferente de distribuições convencionais que acumulam serviços em segundo plano e demandam constantes downloads de pacotes pesados pela rede ou pendrives para restauração, o Gaia OS foi concebido sob três princípios fundamentais:

1. **Eficiência Milimétrica em Hardware Antigo:** Eliminar completamente o desperdício de ciclos de CPU e páginas de memória, aproveitando recursos modernos do kernel Linux (como MGLRU e zRAM) afinados para a microarquitetura Westmere.
2. **Segurança Proativa e Defesa em Profundidade:** Mitigação de vulnerabilidades críticas de dia-zero (como o CVE-2026-98432 no TCP IPv4 e o CVE-2026-111497 'Node2Shell') na borda do sistema, antes mesmo que os pacotes ou códigos atinjam camadas vulneráveis.
3. **Autonomia e Autossuficiência Offline:** Capacidade do próprio sistema operacional construir seus próprios pacotes `.deb`, gerenciar seu repositório APT local offline (`/var/local/gaia-repo`) e criar snapshots incrementais com rollback imediato.

---

## 2. Auditoria e Histórico de Atualizações do Sistema e Segurança

Em Novembro de 2026, o sistema recebeu sucessivas atualizações do Debian Bookworm, Google Chrome, Node.js e ferramentas de desenvolvimento. Cada ciclo foi auditado para garantir compatibilidade com as mitigações e otimizações do Gaia OS:

### 2.1. Kernel Linux (`6.1.190-1` -> `6.1.192-1` / `linux-image-6.1.0-55-amd64`)
* **Linha do Tempo:** Atualizado para `6.1.0-54-amd64` (`6.1.190-1`) em 10/11/2026 e posteriormente para **`6.1.0-55-amd64` (`6.1.192-1`, build 2026-11-14)** em 16/11/2026 (junto com `linux-libc-dev` `6.1.192-1`).
* **Changelog e CVEs:** Incorporou patches upstream para vulnerabilidades de ALSA, temporizadores, `mm/vmscan` (CVE-2026-89753), `mm/migrate` (CVE-2026-89756), `memcg` (CVE-2026-89752), NFS/NFSD e MPTCP syncookies (CVE-2026-97568).
* **Diagnóstico de MGLRU e zRAM:** A inspeção do `/boot/config-6.1.0-55-amd64` confirmou que `CONFIG_LRU_GEN=y` e `# CONFIG_LRU_GEN_ENABLED is not set` (e `CONFIG_ZRAM=m` com `CONFIG_ZRAM_WRITEBACK=y`). Sem nossa configuração persistente, o kernel inicializaria com o MGLRU desativado (`0x0000`).
  * **Conclusão:** `/etc/tmpfiles.d/gaia-mglru.conf` e `/etc/sysctl.d/99-performance.conf` permanecem essenciais e ativos no boot, mantendo MGLRU em `0x0007` e zRAM em `6.0 GiB` (`zstd`).
* **Escudo CVE-2026-98432:** O drop antecipado na tabela `raw` do Netfilter (`gaia-cve-2026-98432-shield.nft`) continua operacional no kernel `6.1.0-55-amd64` (comprovado via simulação real em `gaia-sec-verify`).

### 2.2. Pacotes Críticos de Segurança e Runtimes Atualizados (Novembro/2026)
* **Node.js Global:** Atualizado de `22.23.3` -> `22.23.4` -> **`22.23.5-1nodesource1`** (mitigando CVE-2026-111497 *Node2Shell* e falhas TLS/DNS/Brotli). O script [`tests/verify-security.sh`](file:///home/francisco/Documentos/Projetos/GaiaOS/tests/verify-security.sh) foi corrigido para validar `>= 22.23.4` via `dpkg --compare-versions`.
* **Criptografia, Rede e Bibliotecas Base:** `openssl` e `libssl3` (`3.0.22-1~deb12u2`), `ca-certificates` (`20250419~deb12u2`), `libssh-4` e `libssh-gcrypt-4` (`0.10.6-0+deb12u3`), `libbrotli1` (`1.0.9-2+deb12u1`), `libexpat1` (`2.5.0-1+deb12u5`), `libsasl2-2` (`2.1.28+dfsg-10+deb12u1`), `libsrt1.5-gnutls` (`1.5.1-1+deb12u2`), `apt` (`2.6.2`), `rsync` (`3.5.0+ds1-0+deb12u1`), `imagemagick` (`8:6.9.11.60+dfsg-1.6+deb12u15`), `ntfs-3g` (`1:2022.10.3-1+deb12u4`), `parted` (`3.5-3+deb12u1`), `openjdk-17` (`17.0.21+9-1~deb12u1`), `postgresql-client-15` (`15.20-0+deb12u1`) e `tzdata` (`2026f-0+deb12u1`).
* **Google Chrome 157 (`157.0.8103.50-1` -> `157.0.8103.78-1`):** Políticas corporativas em `/etc/opt/chrome/policies/managed/gaia-performance.json` mantidas com `HighEfficiencyModeEnabled: true` e `MemorySaverModeSavings: 2` (descarte agressivo de abas para poupar RAM).
* **Ferramentas e Navegadores Adicionais:** `firefox` (`160.0~build1` + `firefox-l10n-pt-br`), `google-cloud-cli` (`593.0.0-0`), `code` (`1.146.0`), `cursor` (`3.30.14`), `kiro` (`1.4.154`), `chatgpt` (`26.1111.21308`), `grok-bot` (`1.1.0`). Remoção de `raspi-firmware` desnecessário em `x86_64`.

---

## 3. Arquitetura dos Módulos do Gaia OS

```
                     +---------------------------------------+
                     |              Gaia OS 1.0              |
                     |  Gateway NV55C (Intel Core i7 M 640)  |
                     +-------------------+-------------------+
                                         |
         +-------------------------------+-------------------------------+
         |                               |                               |
+--------v--------+             +--------v--------+             +--------v--------+
|   Segurança     |             |   Performance   |             | Autossuficiência|
|   & Escudos     |             |   & Memória     |             |    & Repositório|
+--------+--------+             +--------+--------+             +--------+--------+
| Netfilter Raw   |             | MGLRU (0x0007)  |             | Repo APT Local  |
| CVE-2026-98432  |             | zRAM zstd (6GB) |             | gaia-pkg        |
| Node2Shell      |             | Chrome Max Saver|             | gaia-snapshot   |
| Hardening Ativos|             | Socket Docker   |             | Zero-Network    |
+--------+--------+             +--------+--------+             +-----------------+
         |                               |
         +---------------+---------------+
                         |
           +-------------v-------------+
           |     Gaia Guardian AI      |
           +-------------+-------------+
           | C Daemon (< 1 MB RSS)     |
           | Telemetria /sys hwmon     |
           | Anti-Freeze & PSI Watchdog|
           | Gemini 3.8 Flash Advisor  |
           | PyQt5 UI (Sob Demanda)    |
           +---------------------------+
```

---

### Módulo 1: Segurança Proativa & Mitigações de Vulnerabilidades

1. **Kernel IPv4 TCP (CVE-2026-98432 - CVSS 9.8):**
   * **Causa Raiz:** Corrupção de memória e corrida no manuseio de opções IPv4 e cabeçalhos estendidos em conexões TCP de alta taxa.
   * **Mitigação:** Regra Netfilter Raw descartando pacotes com `ip hdrlength > 5` direcionados a portas TCP locais, drop de pacotes com opção TCP MPTCP (30), desativação de `net.mptcp.enabled = 0`, desativação de IPv4 Source Routing e ativação de RFC 1337 (`net.ipv4.tcp_rfc1337 = 1`).
   * **Persistência:** Serviço systemd `/etc/systemd/system/gaia-security-shield.service`.

2. **Node.js (CVE-2026-111497 'Node2Shell', CVE-2026-105482, CVE-2026-105483, CVE-2026-106072):**
   * **Mitigação:** Atualização do runtime local do Codex para `v24.22.1` e implantação do hook de runtime `/etc/gaiaos/security/gaia-node-shield.cjs` injetado via `NODE_OPTIONS=--require`, neutralizando NUL bytes em resolução DNS, domínios TLS com caracteres Unicode full-width e endereços IPv4 octais/hexadecimais não-canônicos.

3. **PHP2Shell (CVE-2026-109618 / 109619):**
   * **Mitigação:** Criação de `/etc/gaiaos/security/99-gaia-php2shell-shield.ini` desativando funções de execução arbitrária (`system`, `exec`, `passthru`, `proc_open`, etc.) e desabilitando upload de arquivos em instâncias PHP locais de desenvolvimento.

4. **Blindagem de Ativos Locais e Credenciais:**
   * Diretórios sensíveis (`~/.ssh`, `~/chaves_e_pem`, `~/.aws`, `~/.config/gcloud`) restritos para permissão octal `0700`.
   * Arquivos de credenciais (`client_secret` OAuth, `.env`, chaves `.pem`, `known_hosts`) restritos para permissão octal `0600`.
   * Remoção de containers Docker órfãos que mantinham portas como `0.0.0.0:5432` expostas desnecessariamente.

---

### Módulo 2: Otimização de Memória & Kernel para Westmere

1. **Multi-Gen LRU (MGLRU):**
   * O algoritmo tradicional de substituição de páginas do Linux (active/inactive lists) sofre de "thrashing" em multitarefa pesada quando a memória disponível cai abaixo de 20%.
   * O MGLRU organiza as páginas em múltiplas gerações cronológicas e protege o working set da interface gráfica.
   * Ativação persistente via `/etc/tmpfiles.d/gaia-mglru.conf`:
     * `/sys/kernel/mm/lru_gen/enabled = 7` (0x0007: Pagecache + Memória Anônima + Shmem).
     * `/sys/kernel/mm/lru_gen/min_ttl_ms = 1000` (Protege páginas ativas por 1 segundo).

2. **Ajuste Fino do zRAM:**
   * Configurado para `6.0 GiB` com compressão `zstd` (taxa de compressão média de 3.6x a 4.1x).
   * `vm.page-cluster = 0` configurado em `/etc/sysctl.d/99-performance.conf`: desativa a leitura antecipada de 32 KB de swap convencional, otimizando o acesso aleatório de baixa latência da memória comprimida na CPU Westmere.

3. **Desativação de Serviços Ociosos:**
   * Docker configurado em **Socket Activation** (`systemctl disable docker && systemctl enable docker.socket`). O daemon do Docker só é iniciado na memória quando o comando `docker` for invocado, liberando ~150 MB de RAM.
   * `ModemManager` e `fwupd` desativados e mascarados, pois a máquina não possui modem celular nem BIOS atualizável via fwupd.

---

### Módulo 3: Autossuficiência Offline (Pacotes & Snapshots)

1. **Repositório APT Local (`/var/local/gaia-repo`):**
   * Configurado na lista de fontes do sistema (`/etc/apt/sources.list.d/gaia-local.list`).
   * Permite instalar, atualizar e reconstruir componentes do Gaia OS sem conexão de rede.

2. **Construtor de Pacotes (`/usr/local/bin/gaia-pkg`):**
   * Constrói pacotes `.deb` a partir de estruturas padronizadas de diretório com arquivo `DEBIAN/control`.
   * Gera somas criptográficas `Packages.gz` e `Release` atualizando o repositório local instantaneamente.

3. **Gerenciador de Snapshots (`/usr/local/bin/gaia-snapshot`):**
   * Cria backups de estado das configurações críticas (`/etc/sysctl.d`, `/etc/gaiaos`, `/etc/tmpfiles.d`, systemd units) e da lista de pacotes do sistema.
   * Suporta criação com `gaia-snapshot create "nome"` e restauração automática com `gaia-snapshot rollback <id>`.

---

### Módulo 4: Gaia Guardian AI (C Daemon & Gemini 3.8 Flash)

Para monitorar e otimizar a máquina em tempo real sem comprometer os escassos 5.5 GiB de RAM, desenvolvemos uma arquitetura híbrida inteligente:

1. **Daemon Nativo em C (`gaia-guardian`):**
   * Código em C padrão sem dependências de frameworks pesados (`glibc` pura).
   * Consumo residente de memória: **~924 KB de RAM (RSS)** (menos de 1 MB!).
   * Lê diretamente as métricas de hardware:
     * Sensores de temperatura `coretemp` via `/sys/class/hwmon/hwmon*/temp*_input`.
     * Memória física e zRAM via `/proc/meminfo`.
     * Pressão de stalls de memória via `/proc/pressure/memory` (PSI).
     * Estado do MGLRU via `/sys/kernel/mm/lru_gen/enabled`.
   * Registra telemetria a cada 10 segundos em `/var/log/gaia-guardian/status.json`.
   * **Watchdog Anti-Congelamento:** Se o PSI `full avg10` exceder 25%, aciona proativamente `posix_fadvise` e sincronização de páginas limpas para evitar que o sistema trave.

2. **Consultor Efêmero Gemini 3.8 Flash (`gaia-gemini-advisor`):**
   * Invocado apenas quando necessário (análise sob demanda ou anomalia grave).
   * Utiliza a chave `GEMINI_API_KEY` do ambiente para consultar o modelo `gemini-3.8-flash`.
   * Recebe as métricas de telemetria e retorna uma recomendação estruturada em JSON (`action`, `reason`, `advice`).
   * Consumo residente em segundo plano: **Zero bytes de RAM** (o processo nasce, consulta a API e se encerra imediatamente).

3. **Interface Gráfica Sob Demanda (`gaia-guardian-ui`):**
   * Aplicação em PyQt5 acessível via menu de aplicativos ou pelo comando `gaia-guardian-ui`.
   * Apresenta medidores visuais de RAM, zRAM, temperatura da CPU, alertas recentes e conselhos do Gemini.
   * O usuário pode abrir para inspecionar e fechar a qualquer momento; nenhuma janela ou processo gráfico permanece ocupando memória quando fechado.

---

### Módulo 5: Atalho `agy --yolo`

Com a migração do legado `gemini-cli` para o **Antigravity CLI (`agy`)**, o usuário estava habituado à conveniência da flag `--yolo` para aprovação automática de comandos e ferramentas.

* **Implementação:**
  * Wrapper executável universal em `/usr/local/bin/agy`.
  * Função exportada em `/home/francisco/.bashrc`, `/root/.bashrc` e `/etc/bash.bashrc`.
* **Comportamento:**
  * Qualquer invocação de `agy --yolo <comandos>` intercepta o argumento `--yolo` e o traduz transparentemente para `--dangerously-skip-permissions`.
  * O binário oficial do `agy` é preservado e todas as demais flags e subcomandos continuam funcionando perfeitamente.

---

### Módulo 6: Integração Muse Wonder 1.0 (Meta Frontier Agent & Vertex AI Serverless)

Ativação e integração do modelo de engenharia de software **Meta Muse Wonder 1.0**, provisionado em modo Serverless no **Google Cloud Vertex AI** (projeto `negocio-de-bolso-492422`), tanto no terminal via CLI oficial **Muse Code (`muse`)** quanto no editor **VS Code**.

* **Desafio e Arquitetura da Solução:**
  * O Vertex AI expõe o modelo via Responses API global (`/publishers/meta/v1/responses`) autenticada com Bearer Tokens de curta duração do Google Cloud.
  * A CLI oficial `muse` (v1.4.15) espera o catálogo em `/muse-code/models` e autenticação com API Key estática.
  * Solução: Implementação do daemon local **`gaia-muse-vertex-bridge`** em Python padrão (porta `127.0.0.1:18787`).
* **Recursos do Bridge Local (v2 — Resiliente e Serializado):**
  * **Cache e Renovação de Token:** Executa `gcloud auth print-access-token` para o usuário `francisco` e armazena em cache por 40 minutos com invalidação e renovação automática em caso de HTTP 401.
  * **Serialização e Backoff (Anti-429):** Fila serializada via `threading.Lock()` com intervalo mínimo (0.8s) e retentativa exponencial automática contra rate-limiting do Vertex AI Serverless.
  * **Catálogo e Configuração:** Responde a `/muse-code/models`, `/v1/models` e `/muse-code/config` (`schema_version: 1`) eliminando rajadas de retry na inicialização.
  * **Streaming SSE Transparente e Adaptador OpenAI:** Repassa `POST /v1/responses` em tempo real e traduz `POST /v1/chat/completions` para Vertex AI Responses API com tratamento seguro de `BrokenPipeError`.
  * **Operação Sob Demanda:** Por solicitação do usuário, o daemon `gaia-muse-bridge.service` foi parado e desabilitado da inicialização automática (`systemctl disable`), sendo reativado sob demanda quando `muse` ou `muse-wonder` for invocado.
* **CLI Terminal (`muse` e `muse-wonder`):**
  * Binário oficial isolado em `/opt/muse/bin/` (eliminando alertas de bubblewrap sandbox em diretório home).
  * Wrapper universal `/usr/local/bin/muse` injeta `META_API_KEY="gcp-vertex-proxy"` e garante que o bridge está ativo.
  * Lançador dedicado `/usr/local/bin/muse-wonder` inicia sessões TUI interativas (sem `--disable-reminders`, exclusivo do subcomando `exec`) ou executa prompts headless com reasoning profundo (`high`).
* **Ambiente VS Code:**
  * Extensão **Continue** (`continue.continue`) instalada e configurada com o provedor OpenAI apontando para `http://127.0.0.1:18787/v1` com janela de contexto de 1 milhão de tokens.
  * Perfil de terminal integrado `"Muse Wonder 1.0"` adicionado a `settings.json`.
  * Atalhos no VS Code: `Ctrl+L` para chat interativo com o modelo e `Ctrl+I` para edição/geração inline de código.

---

### Módulo 7: Ambiente Gráfico KDE Plasma 5.27.5 & Recursos Instalados

O Gaia OS 1.0 utiliza o **KDE Plasma `5.27.5`** (baseado no Debian Bookworm) como ambiente de desktop principal, operando com composição leve e integração completa de portais e temas escuros.

1. **Sessão, Gerenciador de Janelas e Display Manager:**
   * **Sessão Ativa:** **Wayland** (`Type=wayland`, `Desktop=KDE`, `State=active`) gerenciada pelo **SDDM (`0.19.0-5`)** com tema `sddm-theme-breeze` (`4:5.27.5-2+deb12u2`).
   * **Compositor KWin:** `kwin-wayland` (`4:5.27.5-3`) como padrão ativo, mantendo `kwin-x11` (`4:5.27.5-3`), `kwin-common` e `kwin-data` como fallback X11.
   * **Workspace e Portais:** `kde-plasma-desktop` (`5:142`), `plasma-desktop` (`4:5.27.5-2`), `plasma-workspace` (`4:5.27.5-2+deb12u2`), `plasma-workspace-wayland` (`4:5.27.5-2+deb12u2`), `plasma-framework` (`5.103.0-1+deb12u1`), `plasma-integration` (`5.27.5-2`), `kde-cli-tools` (`4:5.27.5.1-2`) e `xdg-desktop-portal-kde` (`5.27.5-2`).

2. **Tema Visual e Estética (Breeze Dark):**
   * **Look and Feel Ativo:** `org.kde.breezedark.desktop` (configurado em `~/.config/kdeglobals`).
   * **Pacotes de Estilo:** `breeze` (`4:5.27.5-2`), `breeze-icon-theme` (`4:5.103.0-1`), `breeze-cursor-theme` (`4:5.27.5-2`), `breeze-gtk-theme` (`5.27.5-2`), `kde-style-breeze` (`4:5.27.5-2`), `kwin-style-breeze` (`4:5.27.5-2`) e `kde-style-oxygen-qt5` (`4:5.27.5-2`).

3. **Aplicativos e Utilitários KDE Instalados:**
   * **Produtividade e Base:** `dolphin` (`4:22.12.3-1` — gerenciador de arquivos), `konsole` (`4:22.12.3-1+deb12u1` — terminal), `kate` (`4:22.12.3-1` — editor avançado), `kde-spectacle` (`22.12.3-1` — capturas de tela) e `kde-baseapps` (`4:22.12.3+5.142`).
   * **Gerenciamento de Sistema e Hardware:** `plasma-systemmonitor` (`5.27.5-2`), `plasma-discover` (`5.27.5-2+deb12u1`, com `plasma-discover-backend-fwupd` e `plasma-discover-common`), `plasma-nm` (`4:5.27.5-2` — NetworkManager), `plasma-pa` (`4:5.27.5-2` — áudio PulseAudio/PipeWire), `plasma-disks` (`5.27.5-2` — saúde SMART de discos), `plasma-thunderbolt` (`5.27.5-2`), `plasma-vault` (`5.27.5-2` — cofres criptografados), `powerdevil` (`4:5.27.5-2` — gerenciamento de energia), `bluedevil` (`4:5.27.5-2` — Bluetooth), `kscreen` (`4:5.27.5-2` — gerenciamento de telas) e `plasma-browser-integration` (`5.27.5-2`).
   * **Módulos de Configuração (`System Settings`):** `kde-config-gtk-style`, `kde-config-screenlocker`, `kde-config-sddm`, `kde-config-updates` (`5.27.5-2+deb12u1`), `kde-config-mobile-networking`.
   * **Módulos Mobile / Nano Presentes:** `plasma-mobile` (`5.27.2-1`), `plasma-mobile-tweaks` (`5.27.2-1`), `plasma-nano` (`5.27.5-2`) e `plasma-settings` (`23.01.0-1`).

4. **Plasmoids e Widgets Ativos no Painel e Área de Trabalho:**
   * **Área de Trabalho e Painel Principal (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`):** `org.kde.plasma.folder` (Desktop), `org.kde.panel`, `org.kde.plasma.kickoff` (Menu de Aplicativos), `org.kde.plasma.pager` (Áreas de trabalho virtuais), `org.kde.plasma.icontasks` (Gerenciador de tarefas apenas ícones), `org.kde.plasma.digitalclock`, `org.kde.plasma.showdesktop`, `org.kde.plasma.battery` e `org.kde.plasma.marginsseparator`.
   * **Widget Customizado Instalado pelo Usuário:** `org.kde.plasma.catwalk` em `~/.local/share/plasma/plasmoids/org.kde.plasma.catwalk` (monitor animado de uso de CPU no painel).
   * **Bandeja do Sistema (`org.kde.plasma.systemtray`):** `org.kde.kscreen`, `org.kde.kdeconnect`, `org.kde.plasma.clipboard`, `org.kde.plasma.keyboardlayout`, `org.kde.plasma.devicenotifier`, `org.kde.plasma.notifications`, `org.kde.plasma.manage-inputmethod`, `org.kde.plasma.volume`, `org.kde.plasma.networkmanagement`, `org.kde.plasma.mediacontroller` e `org.kde.plasma.vault`.

---

## 4. Guia Rápido de Comandos do Gaia OS

| Comando | Descrição |
| :--- | :--- |
| `gaia-sec-verify` | Executa a suíte de testes de integridade do Gaia OS (21 testes de segurança, performance e rede). |
| `gaia-guardian-ui` | Abre a interface gráfica de telemetria, saúde do sistema e conselhos da IA. |
| `gaia-gemini-advisor` | Executa uma consulta imediata ao Gemini 3.8 Flash via terminal. |
| `muse` | Inicia o Meta Muse Code CLI oficial conectado ao Muse Wonder 1.0. |
| `muse-wonder "prompt"` | Executa uma tarefa direta com Muse Wonder 1.0 em modo de reasoning alto. |
| `gaia-snapshot list` | Lista todos os pontos de restauração e snapshots salvos. |
| `gaia-snapshot create "motivo"` | Cria um snapshot instantâneo do estado do sistema. |
| `gaia-pkg build <diretorio>` | Constrói um pacote `.deb` e o indexa no repositório APT local. |
| `agy --yolo` | Inicia o Antigravity CLI com aprovação automática de permissões. |

---

## 5. Rastreabilidade de Arquivos do Sistema

* **Repositório Git do Projeto:** [`/home/francisco/Documentos/Projetos/GaiaOS`](file:///home/francisco/Documentos/Projetos/GaiaOS)
* **Daemon Ponte Muse Wonder 1.0:** [`/usr/local/bin/gaia-muse-vertex-bridge.py`](file:///usr/local/bin/gaia-muse-vertex-bridge.py)
* **Serviço Systemd do Bridge:** [`/etc/systemd/system/gaia-muse-bridge.service`](file:///etc/systemd/system/gaia-muse-bridge.service)
* **Lançador Muse Wonder:** [`/usr/local/bin/muse-wonder`](file:///usr/local/bin/muse-wonder)
* **Wrapper Muse CLI:** [`/usr/local/bin/muse`](file:///usr/local/bin/muse)
* **Configuração Continue (VS Code):** [`/home/francisco/.continue/config.json`](file:///home/francisco/.continue/config.json)
* **Configuração do VS Code:** [`/home/francisco/.config/Code/User/settings.json`](file:///home/francisco/.config/Code/User/settings.json)
* **Regras Netfilter Raw:** [`/etc/gaiaos/security/gaia-cve-2026-98432-shield.nft`](file:///etc/gaiaos/security/gaia-cve-2026-98432-shield.nft)
* **Configuração Sysctl de Segurança:** [`/etc/sysctl.d/98-gaia-security-cve-2026-98432.conf`](file:///etc/sysctl.d/98-gaia-security-cve-2026-98432.conf)
* **Ativação Persistente MGLRU:** [`/etc/tmpfiles.d/gaia-mglru.conf`](file:///etc/tmpfiles.d/gaia-mglru.conf)
* **Políticas de Desempenho do Chrome:** [`/etc/opt/chrome/policies/managed/gaia-performance.json`](file:///etc/opt/chrome/policies/managed/gaia-performance.json)
* **Daemon Guardian (Código Fonte C):** [`/home/francisco/Documentos/Projetos/GaiaOS/guardian/src/gaia-guardian.c`](file:///home/francisco/Documentos/Projetos/GaiaOS/guardian/src/gaia-guardian.c)
* **Logs e Telemetria em Tempo Real:** [`/var/log/gaia-guardian/`](file:///var/log/gaia-guardian/)
* **Wrapper Universal agy:** [`/usr/local/bin/agy`](file:///usr/local/bin/agy)
