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
skip_list = ['.*', 'linkdotfiles', 'README.markdown', '*.ps1']
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

# Also link .config files
config_source = os.path.join(cwd, '.config')
config_dest = os.path.join(homedir, '.config')

if os.path.exists(config_source):
    print('Linking .config files...')
    if not os.path.exists(config_dest):
        os.makedirs(config_dest)
        
    for root, dirs, files in os.walk(config_source):
        rel_path = os.path.relpath(root, config_source)
        dest_dir = os.path.join(config_dest, rel_path)
        
        if not os.path.exists(dest_dir):
            os.makedirs(dest_dir)
            
        for file in files:
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
