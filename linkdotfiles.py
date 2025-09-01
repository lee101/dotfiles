#!/usr/bin/env python

"""
Link all the files from the current dir to the homedir as dotfiles.

Works only on Unix-like operating systems that support symlinks (obviously)
"""

import os
from fnmatch import fnmatch
from shutil import rmtree
from optparse import OptionParser

# Parse commmandline options
parser = OptionParser()
parser.add_option("-f", "--force", dest="force", default=False, action="store_true",
                  help="forcibly overwrite files in the homedir when creating links")

(options, args) = parser.parse_args()

# Skip these files (uses fnmatch matching)
skip_list = ['.*', 'linkdotfiles', 'README.markdown', '*.ps1', '*.sh', 'lua', 'init.lua']
cwd = os.path.realpath(os.getcwd())
homedir = os.path.expanduser('~')
files = os.listdir(cwd)

for filename in files:
    if True in [fnmatch(filename, pattern) for pattern in skip_list]:
        print('Skipping %s' % filename)
        continue

    source = os.path.join(cwd, filename)
    if os.path.isdir(source):
        print('Skipping directory %s' % filename)
        continue

    destination = os.path.join(homedir, '.' + filename)

    if os.path.lexists(destination):
        if options.force:
            print('Deleting %s' % destination)
            try:
                os.remove(destination)
            except OSError:
                try:
                    rmtree(destination)
                except OSError as e:
                    print('Failed to delete %s' % destination)
                    continue
        else:
            print('Not overwriting %s since the file exists already and force (-f) is not in effect' % destination)
            continue

    print('Creating a link to %s at %s.' % (source, destination))
    os.symlink(source, destination)

print('Done.')

# Handle lib directory files (like git_aliases)
lib_source = os.path.join(cwd, 'lib')
if os.path.exists(lib_source):
    print('Linking lib directory files...')
    for filename in os.listdir(lib_source):
        # Skip winbashrc as it's Windows-specific
        if filename == 'winbashrc':
            continue
        
        source = os.path.join(lib_source, filename)
        if os.path.isfile(source):
            destination = os.path.join(homedir, '.' + filename)
            
            if os.path.lexists(destination):
                if options.force:
                    print('Deleting %s' % destination)
                    try:
                        os.remove(destination)
                    except OSError:
                        print('Failed to delete %s' % destination)
                        continue
                else:
                    print('Not overwriting %s since the file exists already and force (-f) is not in effect' % destination)
                    continue
            
            print('Creating a link to %s at %s.' % (source, destination))
            os.symlink(source, destination)

# Handle Neovim configuration separately
nvim_source_init = os.path.join(cwd, 'init.lua')
nvim_source_lua = os.path.join(cwd, 'lua')
nvim_config_dir = os.path.join(homedir, '.config', 'nvim')

if os.path.exists(nvim_source_init) or os.path.exists(nvim_source_lua):
    print('Setting up Neovim configuration...')
    
    # Create .config/nvim directory if it doesn't exist
    if not os.path.exists(nvim_config_dir):
        os.makedirs(nvim_config_dir)
    
    # Link init.lua
    if os.path.exists(nvim_source_init):
        nvim_dest_init = os.path.join(nvim_config_dir, 'init.lua')
        if os.path.lexists(nvim_dest_init):
            if options.force:
                print('Removing existing %s' % nvim_dest_init)
                try:
                    os.remove(nvim_dest_init)
                except OSError:
                    print('Failed to remove existing init.lua')
            else:
                print('Not overwriting %s since it exists and force (-f) is not in effect' % nvim_dest_init)
        
        if not os.path.lexists(nvim_dest_init):
            print('Creating link %s -> %s' % (nvim_source_init, nvim_dest_init))
            os.symlink(nvim_source_init, nvim_dest_init)
    
    # Link lua directory
    if os.path.exists(nvim_source_lua):
        nvim_dest_lua = os.path.join(nvim_config_dir, 'lua')
        if os.path.lexists(nvim_dest_lua):
            if options.force:
                print('Removing existing %s' % nvim_dest_lua)
                try:
                    if os.path.isdir(nvim_dest_lua):
                        rmtree(nvim_dest_lua)
                    else:
                        os.remove(nvim_dest_lua)
                except OSError:
                    print('Failed to remove existing lua directory')
            else:
                print('Not overwriting %s since it exists and force (-f) is not in effect' % nvim_dest_lua)
        
        if not os.path.lexists(nvim_dest_lua):
            print('Creating link %s -> %s' % (nvim_source_lua, nvim_dest_lua))
            os.symlink(nvim_source_lua, nvim_dest_lua)

# Also link .config files
config_source = os.path.join(cwd, '.config')
config_dest = os.path.join(homedir, '.config')

if os.path.exists(config_source):
    print('Linking .config files...')
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
                print('Skipping %s in .config' % file)
                continue
            src = os.path.join(root, file)
            dst = os.path.join(dest_dir, file)
            
            if os.path.lexists(dst):
                print('Removing existing %s' % dst)
                try:
                    os.remove(dst)
                except OSError:
                    try:
                        rmtree(dst)
                    except OSError as e:
                        print('Failed to delete %s' % dst)
                        continue
                        
            print('Creating link %s -> %s' % (src, dst))
            os.symlink(src, dst)
