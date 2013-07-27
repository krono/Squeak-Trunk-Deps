#!/bin/sh

#set -x
PROGRAM=`echo $0 | sed 's%.*/%%'`

KEEP=0
DEFAULT=trunkimage-deps.dot

if [ "$1" = "-h" -o "$1" = "--help" ]; then
  cat <<EOF 1>&2
$PROGRAM
Take the output of the \`dotify-package-deps' script and
turn it into nice, readable pdfs.

Usage:

  $0 [-h] [-k] [input-file]

    -h		print this page
    -k		keep intermediate files

    input-file	file to process (defaults to ${DEFAULT})

EOF
  exit 0;
fi

if [ "$1" =  "-k" ]; then
  KEEP=1
  shift
fi

F=$1
if [ -z "$F" ]; then
  F="${DEFAULT}"
fi

if [ ! -f "$F" ]; then
  echo "this is no file: $F"
  exit 1
fi

OUT=$(echo "$F" | sed -E 's/\.[^.]+$//')

WORKING=$(mktemp -q -d -t "$PROGRAM")
if [ $? -ne 0 ]; then
  $ECHO "$0: Can't create temp dir, exiting..."
  exit 1
else
  mkdir -p "${WORKING}"
  trap 'if [ "${KEEP}" -eq 1 ]; then cp -R "${WORKING}/" . ; fi; rm -rf "${WORKING}"' EXIT
fi

set -e

echo "===============\n colour groups \n===============" 1>&2
COLOUR_OUT=$(mktemp -q "${WORKING}/colour.dot")
cp ${F} ${COLOUR_OUT}

sed -i "" -E '/->/!{
 s/"Morphic"/& [color=red]/
 s/"Tools"/& [color=blue]/
 s/"SUnit"/& [color=yellow]/
 s/"Tests"/& [color=yellow]/
 s/"Kernel"/& [color=green]/
 s/"Collections"/& [color=blue]/
}' ${COLOUR_OUT}


echo "======\n tred \n======" 1>&2
TRED_OUT=$(mktemp -q "${WORKING}/tred.dot")

tred "${COLOUR_OUT}" >"${TRED_OUT}"


echo "=========\n cluster \n=========" 1>&2
CLUSTER_OUT=$(mktemp -q "${WORKING}/cluster.dot")

cluster "${TRED_OUT}" | awk '/,$/{printf $0}!/,$/' > "${CLUSTER_OUT}"

echo "===============\n cluster group \n===============" 1>&2
GROUP_PRT=$(mktemp -q "${WORKING}/group_prt.dot")
GROUP_OUT=$(mktemp -q "${WORKING}/group.dot")

set +e

maxcluster=1
grepexit=0
while [ "$grepexit" -eq 0 ]; do
  grep -q "cluster=${maxcluster}" ${CLUSTER_OUT}
  grepexit=$?
  (( maxcluster++ ))
done
grep -v "cluster=" "${CLUSTER_OUT}" > "${GROUP_PRT}"

set -e

cat <<END >${GROUP_OUT}
digraph TrunkDeps {
	graph [ratio=auto,
	       compound=true,
	       concentrate=true,
	       rankdir=RL
	];
	node [style=filled ];
END
grep -e '->' ${GROUP_PRT} >> ${GROUP_OUT}

i=1
while [ $i -le $maxcluster ]; do
   echo "	subgraph cluster_$i {"
   grep "cluster=$i" "${CLUSTER_OUT}" | sed -E "
s/cluster=[0-9]+,?[	 ]*//;
s/\[\]//;
s/^[ ]*/	/;
s/[	 ]+;$/;/"
   echo "	}"
   (( i++ ))
done >> ${GROUP_OUT}
echo "}" >> ${GROUP_OUT}


cp ${GROUP_OUT} ${OUT}-grouped.dot

echo "==========\n painting \n==========" 1>&2
dot -Tpdf -o ${OUT}.pdf ${GROUP_OUT}
dot -Goverlap=prism ${TRED_OUT} | gvmap -e -k | neato -n2 -Tpdf > ${OUT}-map.pdf

echo "painted ${OUT}.pdf and ${OUT}-map.pdf"
# EOF
