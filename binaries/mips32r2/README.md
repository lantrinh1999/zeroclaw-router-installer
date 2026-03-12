# MIPS32r2 Binaries

Thư mục này chứa binaries cho MIPS32r2 (little-endian, softfloat).

## Compile

```bash
# ZeroClaw
GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -o zeroclaw ./cmd/zeroclaw

# CLIProxyAPI
GOOS=linux GOARCH=mipsle GOMIPS=softfloat go build -o cli-proxy-api ./cmd/cli-proxy-api
```

## Target
- Chip: Ingenic X2000e (Creality K1)
- Arch: MIPS32r2, little-endian, softfloat
- Kernel: 4.4.94+
- Flags: `noreorder, pic, cpic, nan2008, o32, mips32r2`
