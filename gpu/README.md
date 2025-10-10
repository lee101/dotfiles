# CUDA Auto-Setup

Add to ~/.bashrc:
```bash
[ -f ~/code/dotfiles/gpu/cuda_autosetup.sh ] && source ~/code/dotfiles/gpu/cuda_autosetup.sh
```

Clear cache after CUDA updates:
```bash
~/code/dotfiles/gpu/cuda_cache_clear.sh
```