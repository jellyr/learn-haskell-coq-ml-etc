#!/bin/bash

. ./base.sh

section start
stack exec m -- -p 3000 &
x3000=$!
stack exec m -- -p 3001 &
x3001=$!
stack exec m -- -p 3002 &
x3002=$!

section sleep
sleep 2

section register
curl localhost:3000/register?localhost:3001
curl localhost:3000/register?localhost:3002

curl localhost:3001/register?localhost:3000
curl localhost:3001/register?localhost:3002

curl localhost:3002/register?localhost:3000
curl localhost:3002/register?localhost:3001

section kill
echo kill ${x3000} ${x3001} ${x3002}


