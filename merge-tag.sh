#!/bin/bash
# AOSP tag merge script for aosp-gr
# Author: Adithya R (ghostrider-reborn)
#
# Usage (from source root):
#    ./manifest/merge-tag.sh <TAG>

# Colors
red=$'\e[1;31m'
grn=$'\e[1;32m'
blu=$'\e[1;34m'
end=$'\e[0m'

REMOTE="gr"
BRANCH="13"

BLACKLIST="hardware/qcom/display \
hardware/qcom/gps \
hardware/qcom/media \
hardware/qcom/wlan"

# verify tag
if [ -z "$1" ]; then
    echo -e "Unspecified tag!\nUsage: ./manifest/merge-tag.sh <TAG>"
    exit 1
else
    TAG="$1"
fi

if ! wget -q --spider https://android.googlesource.com/platform/manifest/+/refs/tags/$TAG; then
    echo "Invalid tag: $TAG!"
    exit 1
fi

# fetch all existing repos
echo "${blu}Fetching list of repos to be merged...$end"
REPOS=$(repo forall -v -c "if [ \"\$REPO_REMOTE\" = \"$REMOTE\" ]; then echo \$REPO_PATH; fi")
echo $REPOS

# save root dir
src_root=$(pwd)

# initialize some files
for file in failed success unchanged; do
    rm -f $file
    touch $file
done

# main
for repo in $REPOS; do echo;
    if [[ $BLACKLIST =~ $repo ]]; then
        echo -e "$repo is in blacklist, skipped"
        continue
    fi

    if ! grep -q "path=\"$repo\"" manifest/default.xml; then
        echo "${red}$repo not found in AOSP manifest, skipping..."
        continue
    fi

    # this is where the fun begins
    echo "${blu}Merging ${repo}..."
    name=$(grep "path=\"$repo\"" manifest/default.xml | sed -e 's/.*name="//' -e 's/".*//')

    cd $repo
    git checkout -q $BRANCH &> /dev/null || echo "${red}$repo checkout failed!"

    if ! git fetch -q https://android.googlesource.com/$name $TAG &> /dev/null; then
        echo "${red}$repo fetch failed!"
    else
        if ! git merge FETCH_HEAD -q -m "Merge tag '$TAG' into $BRANCH" &> /dev/null; then
            echo "$repo" >> $src_root/failed
            echo "${red}$repo merge failed!"
        else
            if [[ $(git rev-parse HEAD) != $(git rev-parse $REMOTE/$BRANCH) ]] && [[ $(git diff HEAD $REMOTE/$BRANCH) ]]; then
                echo "$repo" >> $src_root/success
                echo "${grn}$repo merged succesfully!"
            else
                echo "${end}$repo unchanged"
                echo "$repo" >> $src_root/unchanged
                git reset --hard $REMOTE/$BRANCH &> /dev/null
            fi
        fi
    fi

    cd $src_root
done

if [ -s success ]; then
    echo -e "${grn}\nPushing succeeded repos:$end"
    for repo in $(cat success); do
        cd $repo
        echo $repo
        git push -q &> /dev/null || echo "${red}$repo push failed!"
        cd $src_root
    done
fi

if [ -s failed ]; then
    echo -e "$red \nThese repos failed merging:$end"
    cat failed
fi

echo $end
