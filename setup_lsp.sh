#!/usr/bin/env bash
# A Script for explictly telling the lsp which import paths to use
# You need the dcd-client
# The language server first starts the 'dcd' completion server when a request for completion is made

REPO_DIR=$(git rev-parse --show-toplevel);
cd $REPO_DIR;

# Use the newest serve-d socket file
if pgrep dcd-server; then
	SOCKET_FILE=$(ls /tmp/workspace-d* | tail -1);
else
	echo "dcd-server is not running" && exit 1;
fi

#echo $SOCKET_FILE;
IMPORT_PATH=$REPO_DIR/src/*;

IMPORTS=$(for P in $IMPORT_PATH; do echo -I="$P"; done);
IMPORTS+=" $REPO_DIR/bdd/";
# echo $IMPORTS;

DCD_CLIENT="${DCD_CLIENT:-dcd-client}";

# Use binaries form vscode code-d extension
key="$1"; shift;
case $key in
	--code)
		DCD_CLIENT="$HOME/.local/share/code-d/bin/dcd-client";
	;;
esac

$DCD_CLIENT --socketFile=$SOCKET_FILE $IMPORTS;