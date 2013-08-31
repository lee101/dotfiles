#!/bin/bash
if [[ -s $HOME/.rvm/scripts/rvm ]] ; then source $HOME/.rvm/scripts/rvm ; fi

source $HOME/.vagrantrc/bashrc

PATH=/usr/local/bin:$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting

