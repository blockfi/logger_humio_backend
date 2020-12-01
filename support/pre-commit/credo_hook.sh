#!/bin/bash

credo_args=""

for i in "$@"; do
  credo_args+="--files-included $i "
done

mix credo $credo_args
