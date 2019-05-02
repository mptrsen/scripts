#!/bin/bash

# Installs the base system with many packages I need for my work.
# In particular, this installs:
# - an up-to-date version of R
# - the TeX Live 2018 distribution
# - everything I need to compile stuff
# - git, vim, mutt, etc

script_path=$0

# normal packages from the base repo
read -n 1 -p "Install the base packages? [y/n] "
echo
if [[ "$REPLY" = 'y' ]]; then
	# install the rest of the base packages
	echo "## Installing all base packages"
	sudo apt-get install $(sed -ne '1,/^__BEGIN_PACKAGES__/d;/^__END_PACKAGES__/,$d;p' $script_path | tr '\n' ' ') # the packages listed at the end of this script
fi

# install R from CRAN
# add the repo for CRAN R for Ubuntu 18.04
read -n 1 -p "Install R from CRAN? [y/n] "
echo
if [[ "$REPLY" = 'y' ]]; then
	echo "## Adding the CRAN repo"
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 # add the repo key
	if ! grep "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" /etc/apt/sources.list; then
		sudo echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" >> /etc/apt/sources.list
	fi
	sudo apt-get update

# install R base
	echo "## Installing R"
	sudo apt-get install r-base r-base-dev
fi

read -n 1 -p "Install TeX Live? [y/n] "
echo
if [[ "$REPLY" = 'y' ]]; then
	# Download TeX Live installer
	texlive_url='http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz'
	year=$(date +%Y)
	echo "## Downloading TeX Live $year: $texlive_url"
	wget -nv --show-progress "$texlive_url"
	texlive_dir="~/local/share/texlive/$year"
	echo "## Installing TeX Live $year to $texlive_dir"
	echo "## This will take about two hours"
	tar -xf $(basename install-tl-unx.tar.gz)
	cd install-tl-$year*
	mkdir -p $texlive_dir

	# use TeX Live profile from the end of this script and install TeX Live
	sed -ne '1,/^__BEGIN_TEXLIVE_PROFILE__/d;/^__END_TEXLIVE_PROFILE__/,$d;p' $script_path | sed -e "s#USER_HOME#$HOME#" > texlive.profile
	./install-tl --profile texlive.profile
	echo "## TeX Live $year installed"
	echo "## Installing additional TeX packages"
	sed -ne '1,/^__BEGIN_TEXLIVE_PACKAGES__/d;/^__END_TEXLIVE_PACKAGES__/,$d;p' $script_path | xargs tlmgr install {} \;
	# return to previous directory. This is actually important
	# so the package list and texlive profile at the end don't get mixed up with
	# the code
	cd - > /dev/null
	echo "## Done"
fi

echo '## All done. Bye!'
exit 0 # end the script!

__BEGIN_PACKAGES__
autoconf
automake
build-essential
claws-mail
cmake
conky
ctags
curl
davfs2
default-jre
dos2unix
dstat
emboss
fonts-ebgaramond
gimp
git
gnuplot
gnutls-bin
graphviz
htop
id3v2
imagemagick
imapfilter
inkscape
irssi
isync
jq
lftp
libboost-all-dev
libclass-dbi-mysql-perl
libclass-dbi-perl
libclass-dbi-sqlite-perl
libcurl4-openssl-dev
libjpeg62
libreoffice-java-common
libsasl2-2
libssl-dev
libxml2-dev
lmodern
lynx
mc
mplayer
msmtp
mutt
mysql-client
mysql-server
ngircd
openbox
openssh-server
openssl
pandoc
pandoc-citeproc
parallel
perl-doc
pmount
python-apsw
rsnapshot
rss2email
sqlite3
sshfs
terminator
tmux
tree
urlview
vim-gtk
vim-latexsuite
vorbis-tools
whois
xboard
youtube-dl
zsh
__END_PACKAGES__

__BEGIN_TEXLIVE_PROFILE__
# texlive.profile written on Thu Sep 27 12:46:08 2018 UTC
# It will NOT be updated and reflects only the
# installation profile at installation time.
selected_scheme scheme-custom
TEXDIR USER_HOME/local/share/texlive/2018
TEXMFCONFIG ~/.texlive2018/texmf-config
TEXMFHOME ~/texmf
TEXMFLOCAL USER_HOME/local/share/texlive/texmf-local
TEXMFSYSCONFIG USER_HOME/local/share/texlive/2018/texmf-config
TEXMFSYSVAR USER_HOME/local/share/texlive/2018/texmf-var
TEXMFVAR ~/.texlive2018/texmf-var
binary_x86_64-linux 1
collection-basic 1
collection-bibtexextra 1
collection-binextra 1
collection-context 1
collection-fontsextra 1
collection-fontsrecommended 1
collection-fontutils 1
collection-langenglish 1
collection-langeuropean 1
collection-langfrench 1
collection-langgerman 1
collection-langitalian 1
collection-latex 1
collection-latexrecommended 1
collection-luatex 1
collection-mathscience 1
collection-metapost 1
collection-plaingeneric 1
collection-xetex 1
instopt_adjustpath 0
instopt_adjustrepo 1
instopt_letter 0
instopt_portable 0
instopt_write18_restricted 1
tlpdbopt_autobackup 1
tlpdbopt_backupdir tlpkg/backups
tlpdbopt_create_formats 1
tlpdbopt_desktop_integration 1
tlpdbopt_file_assocs 1
tlpdbopt_generate_updmap 0
tlpdbopt_install_docfiles 1
tlpdbopt_install_srcfiles 1
tlpdbopt_post_code 1
tlpdbopt_sys_bin /usr/local/bin
tlpdbopt_sys_info /usr/local/share/info
tlpdbopt_sys_man /usr/local/man
tlpdbopt_w32_multi_user 1
__END_TEXLIVE_PROFILE__

__BEGIN_TEXLIVE_PACKAGES__
currvita
sectsty
breakurl
enumitem
environ
appendix
lettrine
textpos
quotchap
tabu
tocloft
titling
titlesec
sourcecodepro
makecell
minifp
import
lastpage
tabulary
multirow
threeparttable
threeparttablex
trimspaces
varwidth
wrapfig
__END_TEXLIVE_PACKAGES__
