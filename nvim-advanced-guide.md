# Neovim Advanced Features Guide

## Line Movement (Just Added!)

Move lines or blocks of text up and down:

```
Alt+Up       Move current line up
Alt+Down     Move current line down

In Visual mode:
Alt+Up       Move selected lines up
Alt+Down     Move selected lines down
```

Works in Normal, Insert, and Visual modes!

## Multi-Cursor / Multi-Selection Techniques

### 1. Visual Block Mode (Built-in)
The most powerful native multi-cursor feature:

```
Ctrl-v       Enter visual block mode
I            Insert at beginning of block
A            Append at end of block  
c            Change selected block
```

**Example:** Add text to multiple lines:
1. `Ctrl-v` to enter visual block
2. Select lines with `j`/`k`
3. `I` to insert at beginning
4. Type your text
5. `Esc` to apply to all lines

### 2. Dot Repeat Method
For simple repetitive changes:

```
ciw          Change inner word
n            Next occurrence
.            Repeat last change
```

**Example:** Rename variable:
1. `/oldname` to search
2. `ciw` to change word
3. Type new name
4. `n` to next occurrence
5. `.` to repeat change

### 3. Macros for Complex Multi-Edit
Record and replay commands:

```
qa           Start recording macro to register 'a'
[commands]   Your editing commands
q            Stop recording
@a           Play macro
@@           Repeat last macro
10@a         Play macro 10 times
```

**Example:** Add semicolon to multiple lines:
1. `qa` start recording
2. `A;` append semicolon
3. `j` go to next line
4. `q` stop recording
5. `10@a` apply to next 10 lines

### 4. Search and Replace
Powerful regex-based multi-edit:

```
:%s/old/new/g       Replace all in file
:%s/old/new/gc      Replace with confirmation
:5,20s/old/new/g    Replace in lines 5-20
:'<,'>s/old/new/g   Replace in visual selection
```

**Advanced patterns:**
```
:%s/\<word\>/new/g  Match whole words only
:%s/^/prefix/       Add prefix to all lines
:%s/$/suffix/       Add suffix to all lines
```

### 5. Global Commands
Execute commands on matching lines:

```
:g/pattern/d        Delete lines matching pattern
:g/pattern/t$       Copy matching lines to end
:g/pattern/m$       Move matching lines to end
:g/pattern/normal A;  Append ; to matching lines
```

## Advanced Text Objects

### Custom Text Objects
Beyond the basics (iw, i", i(, etc.):

```
ia           Inside argument (with mini.ai)
aa           Around argument
ii           Inside indentation level
ai           Around indentation level
```

### Surround Operations (nvim-surround)
```
ysiw"        Surround word with quotes
yss)         Surround line with parentheses
cs"'         Change surrounding " to '
ds"          Delete surrounding quotes
ySiw[        Surround word with [ ] on new lines
```

## Advanced Navigation

### Jump Lists
```
Ctrl-o       Jump back
Ctrl-i       Jump forward
:jumps       View jump list
```

### Change Lists
```
g;           Go to previous change
g,           Go to next change
:changes     View change list
```

### Marks
```
ma           Set mark 'a' in current position
'a           Jump to line of mark 'a'
`a           Jump to exact position of mark 'a'
''           Jump back to line before last jump
``           Jump back to position before last jump
:marks       List all marks
```

**Special marks:**
```
'.           Last change
'^           Last insert
'[           Start of last change/yank
']           End of last change/yank
```

## Advanced Search Patterns

### Very Magic Mode
Makes regex more like Perl/Python:

```
/\v(word1|word2)    Search for word1 OR word2
/\vword.{3,5}       Word followed by 3-5 chars
/\v<\d{3}>          Exactly 3 digits as whole word
```

### Search History
```
/pattern     Search forward
?pattern     Search backward
/            Repeat last search
q/           Open search history window
q?           Open reverse search history
```

## Window Management

### Advanced Splits
```
:vsp file    Open file in vertical split
:sp file     Open file in horizontal split
Ctrl-w T     Move window to new tab
Ctrl-w r     Rotate windows
Ctrl-w x     Exchange windows
Ctrl-w =     Make all windows equal size
Ctrl-w |     Maximize window width
Ctrl-w _     Maximize window height
```

### Window Commands
```
:only        Close all other windows
:vsplit #    Split with alternate file
:split %:h   Split with current directory
```

## Fold Management

```
zf{motion}   Create fold
zo           Open fold
zc           Close fold
za           Toggle fold
zR           Open all folds
zM           Close all folds
zd           Delete fold
zi           Toggle fold enable
```

## Registers

### Named Registers
```
"ayy         Yank line to register 'a'
"ap          Paste from register 'a'
"Ayy         Append to register 'a'
:reg         View all registers
```

### Special Registers
```
"0           Last yank
"1-"9        Delete history
"-           Small delete
"+           System clipboard
"*           Selection clipboard
".           Last inserted text
"%           Current filename
":           Last command
"/           Last search
"=           Expression register
```

## Command-Line Magic

### Ranges
```
:.           Current line
:$           Last line
:%           Entire file
:'<,'>       Visual selection
:.,.+5       Current line plus next 5
:.-3,.+3     3 lines before and after
```

### Shell Integration
```
:!command    Run shell command
:r !command  Insert command output
:.!command   Filter line through command
:%!sort      Sort entire file
:'<,'>!sort  Sort selection
```

## Expression Register

Use `Ctrl-r =` in insert mode:
```
Ctrl-r =5*5  Insert 25
Ctrl-r =&tw  Insert textwidth value
```

## Quick Tips for Productivity

### 1. Increment/Decrement
```
Ctrl-a       Increment number
Ctrl-x       Decrement number
g Ctrl-a     Sequential increment in visual
```

### 2. Case Changes
```
~            Toggle case
gu{motion}   Lowercase
gU{motion}   Uppercase
g~{motion}   Toggle case
```

### 3. Formatting
```
gq{motion}   Format text
gw{motion}   Format without cursor move
==           Format current line
gg=G         Format entire file
```

### 4. Special Inserts
```
Ctrl-r "     Insert from default register
Ctrl-r %     Insert filename
Ctrl-r /     Insert last search
Ctrl-r :     Insert last command
```

## FZF-Lua Power Features

### Advanced Searching
```
Space fg     Live grep
Space fw     Search word under cursor
Space fW     Search WORD under cursor
Space fr     Resume last search
```

### LSP Integration
```
Space fs     Document symbols
Space fS     Workspace symbols
Space fd     Go to definition
Space fR     Find references
```

## Debugging Tips

### Troubleshooting
```
:checkhealth  System health check
:messages     View messages
:verbose set option?  See where option was set
:scriptnames  List loaded scripts
```

### Performance
```
:syntime on   Profile syntax highlighting
:syntime report
```

## Custom Workflows

### Quick Refactoring
1. Search: `/oldName`
2. Select all: `ggVG`
3. Replace in selection: `:'<,'>s/oldName/newName/g`

### Multi-File Search & Replace
1. `Space fg` to search across files
2. `Tab` to select files in FZF
3. `:cdo s/old/new/g` to replace in quickfix
4. `:wa` to save all

### Quick Macro for List Formatting
1. `qa` start recording
2. `I- ` add bullet point
3. `j` next line
4. `q` stop
5. `10@a` apply to 10 lines

Remember: The key to mastering Neovim is combining these features. Start with Visual Block mode and dot-repeat, then gradually add more advanced techniques to your workflow!