#!/bin/bash

set -e
set -o pipefail

# Pythonbrew utilities

# Detects if pythonbrew is installed
if [[ -s $PYTHONBREW_ROOT ]]
then
	readonly IS_PYTHONBREW_INSTALLED=1
elif [[ -s $HOME/.pythonbrew/etc/bashrc ]]
then
	readonly IS_PYTHONBREW_INSTALLED=1
	readonly PYTHONBREW_ROOT='$HOME/.pythonbrew'
else
	readonly IS_PYTHONBREW_INSTALLED=0
	readonly PYTHONBREW_ROOT='$HOME/.pythonbrew'
fi

readonly PYTHONBREW_ETC="${PYTHONBREW_ROOT}/etc"

[[ -s $PYTHONBREW_ETC ]] && source $PYTHONBREW_ETC/*

function deactivate_pythonbrew()
{
	if [ $IS_PYTHONBREW_INSTALLED == 1 ]
	then
		echo "Pythonbrew installation found at $PYTHONBREW_ROOT"

		pythonbrew_version="$(pythonbrew --version 2>&1)"
		echo "Pythonbrew $pythonbrew_version found."

		echo "Current python version is $(python -V 2>&1)"

		pythonbrew off

		echo "Current python version after pythonbrew deactivation is $(python -V 2>&1)"
	else
		echo "Pythonbrew is not installed. Skipping."
	fi
}

function install_pythonbrew()
{
	if [ $IS_PYTHONBREW_INSTALLED == 0 ]
	then
		curl -kL http://xrl.us/pythonbrewinstall | bash
		append_if_not_found "[[ -s $PYTHONBREW_ROOT/etc/bashrc ]] && source $PYTHONBREW_ROOT/etc/*"
		append_if_not_found 'export PYTHONBREW_ROOT=$HOME/.pythonbrew/'
	fi
}

# Bootstrap utilities

function get_filename_from_url()
{
	python -c "import urlparse;url=urlparse.urlsplit('$1');print(url.path.split('/')[-1])"
	wait
}

function download_and_install()
{
	filename=$(get_filename_from_url $1)
	echo "Downloading $filename"
	curl -O $1

	sudo python $filename
}

function apt_get()
{
	sudo apt-get install $1
}

readonly DISTRIBUTE=http://python-distribute.org/distribute_setup.py
readonly PIP=https://raw.github.com/pypa/pip/master/contrib/get-pip.py

# bashrc utilities

function append_if_not_found()
{
	grep -q "$1" ~/.bashrc || echo "$1" >> ~/.bashrc
}

# Main program

# Default essential packages
packages=( 'yolk' 'fabric' 'nose' 'coverage' 'ipython' 'virtualenv' 'virtualenvwrapper' )

function usage()
{
	echo "This script installs the python essential packages."
	echo "-h, --help Prints the usage and exists."
	echo "-d, --default-packages Prints the default essential packages and exits."
	echo "--no-<package name> excludes a package from the default essential packages and prevents it's installation. Specifying a package more than once is valid and will be ignored."
	echo "--with-<package name> includes a non-defualt essential package to be installed. Specifying a package more than once is valid and will be ignored."
}

function print_packages()
{
	all_packages=("${packages[@]}" 'distribute' 'pip')
	printf '%s\n' "${all_packages[@]}"
	echo "${#all_packages[@]} packages in total."
}

while [ -n "$1" ]
do
	case $1 in
		-h | --help)
			usage
			exit 0
			;;
		-d | --defualt-packages)
			echo "Default essential packages:"
			print_packages
			exit 0
			;;
		--no-pip | --no-virtualenv | --no-distribute)
			package=${1#--no-}
			echo "$package is required."
			exit 1
			;;
		--no-*)
			package=${1#--no-}

			packages=(${packages[@]/$package/})
			;;
		--with-*)
			package=${1#--with-}
			packages+=($package)
			;;
		*)
			echo -e "\e[00;31mInvalid command: $1.\nSee bootstrap.sh -h or bootstrap --help for usage.\e[00m"
			exit 1
			;;
	esac
	shift
done

deactivate_pythonbrew

python_version="$(python -V 2>&1)"

if [ -z "$python_version" ]
then
	echo "Python installation not found. Aborting."
	exit $?
fi

echo "Setting up $python_version essentials."

packages=($(printf '%s\n' "${packages[@]}" | sort -n | uniq))
echo "Installing the following packages:"
print_packages
echo '=================================='

apt_get 'curl'
apt_get 'python-dev'

echo '=================================='

mkdir -p .devenv_temp
cd .devenv_temp

download_and_install $DISTRIBUTE
download_and_install $PIP

echo '=================================='

for package in ${packages[@]}
do
	echo "Installing $package"
	sudo pip install $package
	wait
done

append_if_not_found 'export VIRTUALENV_USE_DISTRIBUTE=true'
append_if_not_found 'export WORKON_HOME=~/.virtualenvs'
append_if_not_found 'export PIP_RESPECT_VIRTUALENV=true'
append_if_not_found 'export PIP_REQUIRE_VIRTUALENV=true'
append_if_not_found 'export PIP_VIRTUALENV_BASE=$WORKON_HOME'
append_if_not_found 'source /usr/local/bin/virtualenvwrapper.sh'

install_pythonbrew

source ~/.bashrc
mkdir -p $WORKON_HOME

cd ../
rm -R .devenv_temp

exit 0
