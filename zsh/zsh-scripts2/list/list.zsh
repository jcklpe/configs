##- List stuff
#List users
alias list-users='cut -d: -f1 /etc/passwd'

#What's installed?
 alias list-npm='npm list -g --depth=0'
 alias list-apt='sudo apt list --installed'

# human readable path check
alias list-path='tr ':' '\n' <<< "$PATH"';

# list deps for a program
list-deps () {
echo "enter Package"
read Package

apt-cache depends --no-pre-depends --no-recommends --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances $Package | grep -E "(qt|gtk|kde)"

}
