#!/bin/bash
set -xme

_quit() {
  kill $(cat /var/run/supervisord.pid)
}

if [ -d /startup-hooks ]; then
  for hook in $(ls /startup-hooks); do
    echo -n "Found startup hook ${hook} ... "
    if [ -x "/startup-hooks/${hook}" ]; then
      echo "executing."
      /startup-hooks/${hook}
    else
      echo 'not executable. Skipping.'
    fi
  done
fi

printf "\n\nStarting supervisor...\n\n"
/usr/bin/supervisord -n
export supervisor_child=${!}
echo ${supervisor_child} >/var/run/supervisord.pid

trap _quit SIGQUIT

echo 'Waiting on child...'
wait ${supervisor_child}