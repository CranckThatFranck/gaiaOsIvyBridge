# Instalar a Gaia OS Ivy Bridge Edition

A imagem é uma ISO híbrida que inicia em **UEFI** por pendrive. Ela abre uma sessão live (KDE Plasma, Wayland) e o instalador Calamares.

## O que você precisa

- O arquivo `gaiaos-ivybridge-1.0-amd64.iso` e o `gaiaos-ivybridge-1.0-amd64.iso.sha256`
- Pendrive de 8 GB ou mais
- O desktop com o i7-3770, placa B75, SSD de 256 GB e boot UEFI

Se a release veio em pedaços (a ISO passou de 2 GB, limite de cada arquivo no GitHub):

```bash
cat gaiaos-ivybridge-1.0-amd64.iso.part* > gaiaos-ivybridge-1.0-amd64.iso
sha256sum -c gaiaos-ivybridge-1.0-amd64.iso.sha256
```

O script `scripts/juntar-iso.sh` faz a mesma coisa. Confira o SHA256 também quando o arquivo vier inteiro.

## Gravar o pendrive

Descubra o dispositivo do pendrive (`lsblk`). No exemplo ele é `/dev/sdX`. Confira duas vezes: `dd` apaga o disco inteiro.

```bash
sudo dd if=gaiaos-ivybridge-1.0-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

No próprio KDE, o programa **ISO Image Writer** (`isoimagewriter`) grava a mesma imagem sem linha de comando.

## Ligar o desktop pelo pendrive

1. Entre na setup AMI (em geral `Del` ou `F2` na B75).
2. O modo de boot tem de ser **UEFI**, não CSM/legado.
3. Se o pendrive não aparecer na lista de boot, desligue o Secure Boot, grave de novo e tente outra vez. A imagem inclui shim assinado; placas B75 de 2012 nem sempre aceitam a chave.
4. Escolha o pendrive no menu de boot (`F10` ou `F12`, depende da placa). O GRUB espera 5 segundos e entra na sessão live.

A sessão live entra sozinha como usuário `gaia`, senha `gaia`, teclado ABNT2, fuso `America/Sao_Paulo`, idioma pt_BR, tema Breeze Dark.

## Instalar no SSD

Na ISO `ivybridge-v1.0`, o Calamares fecha ao abrir: o branding `gaiaos` dessa imagem não tem `slideshow` nem `images`, e o Calamares 3.3.14 termina o processo nesse caso. Antes de clicar no ícone, no terminal da sessão live:

```bash
sudo sed -i 's/^branding: gaiaos$/branding: debian/' /etc/calamares/settings.conf
```

O instalador abre com a marca Debian. O sistema instalado continua sendo a Gaia OS. Uma ISO posterior já traz o slideshow e os logotipos.

Abra **Instalar Gaia OS** na área de trabalho.

O Calamares sugere, ao apagar o disco:

- EFI FAT32 de 600 MiB em `/boot/efi` (rótulo `GAIAEFI`)
- `/boot` ext4 de 1 GiB
- o resto do SSD em `/` ext4, com `discard` (TRIM)

Não há partição de swap. O sistema usa zRAM. Você também pode particionar à mão, desde que a tabela seja GPT e exista uma EFI.

Crie o seu usuário com sudo. A conta `gaia` da sessão live não é copiada para o SSD. A senha de root fica bloqueada: o usuário criado usa `sudo`.

O GRUB é instalado em modo UEFI (identificador `debian`, que é o que o pacote `grub-efi` do Debian espera) com a entrada "Gaia OS".

## Depois da primeira inicialização

A rede cabeada (RTL8111, módulo `r8169`) deve subir pelo NetworkManager. O pacote `firmware-realtek` traz `rtl_nic/rtl8168h-2.fw`. O `intel-microcode` entra no initramfs e substitui o microcódigo 0x21 que a BIOS deixa carregado, se a Intel já publicou um mais novo no pacote.

Atualizações:

- Todo dia, `unattended-upgrades` aplica a segurança do Debian.
- Toda semana, `gaia-update.timer` cria um snapshot (`gaia-snapshot`), roda `apt full-upgrade` (isso inclui kernel novo) e instala o `gaiaos-core` mais novo entre as releases `gaiaos-core-*`, conferindo o SHA-256 publicado na API.
- Na hora: `sudo gaia-update`
- Só os escudos e ferramentas Gaia: `sudo gaia-update --tools`
- Voltar configurações: `gaia-snapshot list` e `gaia-snapshot rollback`
- Kernel anterior: no menu do GRUB. O atualizador não apaga o kernel antigo.

O backports fica disponível com prioridade 100. Nada de lá é instalado sozinho. Para um pacote específico: `sudo apt install -t trixie-backports <pacote>`.

## Reconstruir a ISO

Na raiz do repositório:

```bash
./scripts/build-iso.sh
```

O script pede sudo, gera o `.deb` `gaiaos-core` e chama o `live-build` do Debian 13. A ISO sai em `dist/gaiaos-ivybridge-1.0-amd64.iso`. O workflow `.github/workflows/build-iso.yml` faz o mesmo no GitHub quando a tag `ivybridge-v*` é enviada, e publica os arquivos na release.
