#!/bin/bash

ENVFILE="/etc/environment"
PTYPE="http https"
APTFILE="/etc/apt/apt.conf.d/95proxies"

function usage {
  echo -ne "\n"
  echo -ne $0
  echo -ne " [-h] | [-s <proxy>] | [-n <noproxy] | [-c] | [-p] | [-t] | [-g]\n"
  echo -ne "-h print this message\n"
  echo -ne "-s set new proxy address\n"
  echo -ne "-n set comma separated list of address/domains for which to bypass the proxy\n"
  echo -ne "-c clean up proxy setting\n"
  echo -ne "-g print proxy address\n"
  echo -ne "-p port number\n"
  echo -ne "-t proxy on/off, leaving proxy address in config files\n\n"
}

function getProxy {
  while read line; do
    tmp=`echo $line | sed -e 's/^#*\(.*_proxy=\|.*_PROXY=\)\([^:]*\):\/\/\([^:]*\):\([0-9]*\) */a=\2 b=\3 c=\4/'`
    eval $tmp
    if [ "$a" == "$1" ]; then
      return
    fi
  done < ${ENVFILE}
}

function setProxy {
  p=$1
  q=$2
  for ptype in ${PTYPE}; do
    pvar=$ptype\_proxy
    hpvar=`echo $pvar | tr [a-z] [A-Z]`
    pvar="$pvar=${ptype}://$p:$q"
    hpvar="$hpvar=${ptype}://$p:$q"
    echo $pvar >> ${ENVFILE}
    echo $hpvar >> ${ENVFILE}
    echo "Acquire::${ptype}::proxy \"${ptype}://${p}:${q}\";" >> ${APTFILE}
  done
  gsettings set org.gnome.system.proxy mode 'manual' 
  gsettings set org.gnome.system.proxy.http host $p
  gsettings set org.gnome.system.proxy.http port $q
}

if [ $# -lt 1 ]; then
  usage
  exit
fi

port=8080

while getopts s:p:htcg opt
do
  case "$opt" in
    p)
      port=$OPTARG
    ;;
    s|t|c|g)
      if [ -n "$op" ]; then
        usage
        exit
      fi
      if [ "$opt" == "s" ]; then
        proxy=$OPTARG
      fi
      op=$opt
    ;;
    h|\?)
      usage
      exit
    ;;
  esac
done

if [ "$op" == "s" ] || [ "$op" == "c" ]; then
  for var in `env | sed -e 's/^\(.*proxy\|.*PROXY\)=.*\|.*/\1/'`
  do
    [ -n $var ] && unset $var
  done

  sed -i 's/^\(.*proxy\|.*PROXY\)=.*//' ${ENVFILE}
  sed -i '/^$/d' ${ENVFILE}
  gsettings reset-recursively org.gnome.system.proxy
  rm -f ${APTFILE}

  if [ "$op" == "s" ]; then
    setProxy $proxy $port
  fi
fi

if [ $op == "t" ]; then
  nc=`grep -c '^[^#]*\(proxy\|PROXY\)' ${ENVFILE}`
  c=`grep -c '^#.*\(proxy\|PROXY\)' ${ENVFILE}`
  echo "$c -- $nc"
  if [ $nc -eq 0 ] && [ $c -eq 0 ]; then
    echo "Proxy not set. use '-s'"
    exit
  fi
  if [ $c -eq 0 ]; then
    sed -i 's/^\([^#]*proxy=\|.*PROXY=\)/#\1/g' ${ENVFILE}
    gsettings reset-recursively org.gnome.system.proxy
    rm -f ${APTFILE}
  else
    getProxy http
    sed -i 's/^\(.*proxy\|.*PROXY\)=.*//' ${ENVFILE}
    sed -i '/^$/d' ${ENVFILE}
    setProxy $b $c
  fi
fi

if [ $op == "g" ]; then
  getProxy https
  echo "$a $b $c"
  getProxy http
  echo "$a $b $c"
fi

