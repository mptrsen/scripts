#!/bin/bash

wget http://evol.mcmaster.ca/~brian/evoldir/last.day -O /tmp/evoldir.last.day
# subshell
(echo "Subject: evoldir last day"; cat /tmp/evoldir.last.day) | /usr/sbin/sendmail mptrsen@uni-bonn.de
