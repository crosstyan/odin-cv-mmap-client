# Play with Odin the language

## Install

```bash
wget https://f001.backblazeb2.com/file/odin-binaries/nightly/odin-linux-amd64-nightly%2B2025-01-08.tar.gz
tar -xzf odin-linux-amd64-nightly+2025-01-08.tar.gz
sudo mv odin-linux-amd64-nightly+2025-01-08 /opt/odin
sudo ln -s /opt/odin/odin /usr/local/bin/odin

# or add to your PATH in your .bashrc or .zshrc
export PATH=$PATH:/opt/odin
```

## Language Server

See [DanielGavin/ols](https://github.com/DanielGavin/ols)

```bash
git clone https://github.com/DanielGavin/ols
cd ols
./build.sh
cp ols /opt/odin
./odinfmt.sh
cp odinfmt /opt/odin
# add them to your PATH or link them to /usr/local/bin
```

In your editor, configure the path to the Odin Language Server:

Visual Studio Code for example:

```jsonc
{
  // ...
  "ols.server.path": "/opt/odin/ols"
}
```
