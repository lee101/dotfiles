#!/usr/bin/env python

"""
Link all the files from the current dir to the homedir as dotfiles.

Works only on Unix-like operating systems that support symlinks (obviously)
"""

import os
import sys
from fnmatch import fnmatch
from shutil import rmtree
from optparse import OptionParser

# Parse commmandline options
parser = OptionParser()
parser.add_option("-f", "--force", dest="force", default=False, action="store_true",
                  help="forcibly overwrite files in the homedir when creating links")
parser.add_option("-q", "--quiet", dest="quiet", default=False, action="store_true",
                  help="only print warnings and errors")

(options, args) = parser.parse_args()

def log(message):
    if not options.quiet:
        print(message)

def warn(message):
    print(message, file=sys.stderr)

# Skip these files (uses fnmatch matching)
skip_list = ['.*', 'linkdotfiles', 'README.markdown', '*.ps1', '*.sh', 'lua', 'init.lua', 'gitconfig.windows']
cwd = os.path.realpath(os.getcwd())
homedir = os.path.expanduser('~')
files = os.listdir(cwd)

for filename in files:
    if True in [fnmatch(filename, pattern) for pattern in skip_list]:
        log('Skipping %s' % filename)
        continue

    source = os.path.join(cwd, filename)
    if os.path.isdir(source):
        log('Skipping directory %s' % filename)
        continue

    destination = os.path.join(homedir, '.' + filename)

    if os.path.lexists(destination):
        if options.force:
            log('Deleting %s' % destination)
            try:
                os.remove(destination)
            except OSError:
                try:
                    rmtree(destination)
                except OSError:
                    warn('Failed to delete %s' % destination)
                    continue
        else:
            warn('Not overwriting %s since the file exists already and force (-f) is not in effect' % destination)
            continue

    log('Creating a link to %s at %s.' % (source, destination))
    os.symlink(source, destination)

log('Done.')

# Handle lib directory files (like git_aliases)
lib_source = os.path.join(cwd, 'lib')
if os.path.exists(lib_source):
    log('Linking lib directory files...')
    for filename in os.listdir(lib_source):
        # Skip winbashrc as it's Windows-specific
        if filename == 'winbashrc':
            continue
        
        source = os.path.join(lib_source, filename)
        if os.path.isfile(source):
            destination = os.path.join(homedir, '.' + filename)
            
            if os.path.lexists(destination):
                if options.force:
                    log('Deleting %s' % destination)
                    try:
                        os.remove(destination)
                    except OSError:
                        warn('Failed to delete %s' % destination)
                        continue
                else:
                    warn('Not overwriting %s since the file exists already and force (-f) is not in effect' % destination)
                    continue
            
            log('Creating a link to %s at %s.' % (source, destination))
            os.symlink(source, destination)

# Handle Neovim configuration separately
nvim_source_init = os.path.join(cwd, 'init.lua')
nvim_source_lua = os.path.join(cwd, 'lua')
nvim_config_dir = os.path.join(homedir, '.config', 'nvim')

if os.path.exists(nvim_source_init) or os.path.exists(nvim_source_lua):
    log('Setting up Neovim configuration...')
    
    # Create .config/nvim directory if it doesn't exist
    if not os.path.exists(nvim_config_dir):
        os.makedirs(nvim_config_dir)
    
    # Link init.lua
    if os.path.exists(nvim_source_init):
        nvim_dest_init = os.path.join(nvim_config_dir, 'init.lua')
        if os.path.lexists(nvim_dest_init):
            if options.force:
                log('Removing existing %s' % nvim_dest_init)
                try:
                    os.remove(nvim_dest_init)
                except OSError:
                    warn('Failed to remove existing init.lua')
            else:
                warn('Not overwriting %s since it exists and force (-f) is not in effect' % nvim_dest_init)
        
        if not os.path.lexists(nvim_dest_init):
            log('Creating link %s -> %s' % (nvim_source_init, nvim_dest_init))
            os.symlink(nvim_source_init, nvim_dest_init)
    
    # Link lua directory
    if os.path.exists(nvim_source_lua):
        nvim_dest_lua = os.path.join(nvim_config_dir, 'lua')
        if os.path.lexists(nvim_dest_lua):
            if options.force:
                log('Removing existing %s' % nvim_dest_lua)
                try:
                    if os.path.isdir(nvim_dest_lua):
                        rmtree(nvim_dest_lua)
                    else:
                        os.remove(nvim_dest_lua)
                except OSError:
                    warn('Failed to remove existing lua directory')
            else:
                warn('Not overwriting %s since it exists and force (-f) is not in effect' % nvim_dest_lua)
        
        if not os.path.lexists(nvim_dest_lua):
            log('Creating link %s -> %s' % (nvim_source_lua, nvim_dest_lua))
            os.symlink(nvim_source_lua, nvim_dest_lua)

# Also link .config files
config_source = os.path.join(cwd, '.config')
config_dest = os.path.join(homedir, '.config')

if os.path.exists(config_source):
    log('Linking .config files...')
    if not os.path.exists(config_dest):
        os.makedirs(config_dest)
        
    for root, dirs, files in os.walk(config_source):
        # Remove 'lua' from dirs so os.walk does not descend into it
        if 'lua' in dirs:
            dirs.remove('lua')
        rel_path = os.path.relpath(root, config_source)
        dest_dir = os.path.join(config_dest, rel_path)
        
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
            
        for file in files:
            # Skip .ps1 and .sh files in .config as well
            if fnmatch(file, '*.ps1') or fnmatch(file, '*.sh'):
                log('Skipping %s in .config' % file)
                continue
            if file.lower() == 'readme.md':
                log('Skipping %s in .config' % file)
                continue
            src = os.path.join(root, file)
            dst = os.path.join(dest_dir, file)
            
            if os.path.lexists(dst):
                log('Removing existing %s' % dst)
                try:
                    os.remove(dst)
                except OSError:
                    try:
                        rmtree(dst)
                    except OSError:
                        warn('Failed to delete %s' % dst)
                        continue
                        
            log('Creating link %s -> %s' % (src, dst))
            os.symlink(src, dst)

# Link Windows-specific gitconfig on Windows only
import platform
if platform.system() == 'Windows' or os.name == 'nt':
    win_gitconfig = os.path.join(cwd, 'gitconfig.windows')
    if os.path.exists(win_gitconfig):
        destination = os.path.join(homedir, '.gitconfig.windows')
        if os.path.lexists(destination):
            if options.force:
                log('Deleting %s' % destination)
                try:
                    os.remove(destination)
                except OSError:
                    warn('Failed to delete %s' % destination)
            else:
                warn('Not overwriting %s since it exists and force (-f) is not in effect' % destination)
        if not os.path.lexists(destination):
            log('Creating a link to %s at %s.' % (win_gitconfig, destination))
            os.symlink(win_gitconfig, destination)

# Link .codex directory contents for Codex CLI configuration
codex_source = os.path.join(cwd, '.codex')
codex_dest = os.path.join(homedir, '.codex')

if os.path.exists(codex_source):
    log('Linking .codex files...')
    if not os.path.exists(codex_dest):
        os.makedirs(codex_dest)

    for root, dirs, files in os.walk(codex_source):
        rel_path = os.path.relpath(root, codex_source)
        dest_dir = codex_dest if rel_path == '.' else os.path.join(codex_dest, rel_path)

        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)

        for file in files:
            src = os.path.join(root, file)
            dst = os.path.join(dest_dir, file)

            if os.path.lexists(dst):
                log('Removing existing %s' % dst)
                try:
                    os.remove(dst)
                except OSError:
                    try:
                        rmtree(dst)
                    except OSError:
                        warn('Failed to delete %s' % dst)
                        continue

            log('Creating link %s -> %s' % (src, dst))
            os.symlink(src, dst)
