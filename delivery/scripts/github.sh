#!/bin/bash -e

TAG_PATTERN='[0-9].[0-9]'
DEFAULT_VERSION="0.0"
RELEASE="${RELEASE:-false}"

# Get the server from the git URL.
# For example, from git URL "git@pdihub.hi.inet:awazza/niji-blocking.git", the server is "pdihub.hi.inet".
get_server() {
    local origin="$(git config --get remote.origin.url)"
    case "${origin}" in
        git@*) echo "${origin}" | cut -d: -f1 | cut -d@ -f2 ;;
        https:*) echo "${origin}" | cut -d/ -f3 ;;
        *) return 1 ;;
    esac
}

# Get the user (or organization) from the git URL.
# For example, from git URL "git@pdihub.hi.inet:awazza/niji-blocking.git", the server is "awazza".
get_user() {
    local origin="$(git config --get remote.origin.url)"
    case "${origin}" in
        git@*) echo "${origin}" | cut -d: -f2 | cut -d/ -f1 ;;
        https:*) echo "${origin}" | cut -d/ -f4 ;;
        *) return 1 ;;
    esac
}

# Get the repository from the git URL.
# For example, from git URL "git@pdihub.hi.inet:awazza/niji-blocking.git", the repository "niji-blocking".
get_repo() {
    local origin="$(git config --get remote.origin.url)"
    case "${origin}" in
        git@*) basename $(echo "${origin}" | cut -d/ -f2) .git ;;
        https:*) basename $(echo "${origin}" | cut -d/ -f5) .git ;;
        *) return 1 ;;
    esac
}

# Get the API to interact with git server.
# If the github server is pdihub.hi.inet, the API is https://pdihub.hi.inet/api/v3. Otherwise, https://api.github.com.
get_api() {
    [ "$(get_server)" == "pdihub.hi.inet" ] && echo "https://pdihub.hi.inet/api/v3" || echo "https://api.github.com"
}

# Get last tag that complies with TAG_PATTERN.
# If there is no tag compliant with the TAG_PATTERN, it returns DEFAULT_VERSION.
get_last_tag() {
    tag_commit=$(git rev-list --tags="${TAG_PATTERN}" --max-count=1 2>/dev/null) \
            && git describe --tags "${tag_commit}" \
            || echo "${DEFAULT_VERSION}"
}

# Get next version by using the last tag and incrementing the second digit.
get_next_version() {
    get_last_tag | awk -F. '{print $1"."$2+1}'
}

get_version() {
    [ "${RELEASE}" == "true" ] && get_next_version || get_last_tag
}

# Get revision with the format: ${number_of_commits}.g${sha}
# If it is a release, the number of commits is 0 (because the release would create a tag for this commit).
# If it is not a release, the number of commits is counted since the last tag. However, if there is no tag available,
# then it is counted since the first commit.
get_revision() {
    local sha=$(git rev-parse --short HEAD)
    if [ "${RELEASE}" == "true" ]; then
        commits="0"
    else
        last_tag="$(get_last_tag)"
        if [ "${last_tag}" == "${DEFAULT_VERSION}" ]; then
            last_tag="$(git rev-list --max-parents=0 HEAD)"
        fi
        commits="$(git rev-list --count ${last_tag}..HEAD)"
    fi
    echo "${commits}.g${sha}"
}

# Get the release notes from a last tag to HEAD.
get_release_notes() {
    local last_tag="$(get_last_tag)"
    [ "${last_tag}" == "${DEFAULT_VERSION}" ] && range="HEAD" || range="${last_tag}...HEAD"
    git log "${range}" --pretty=format:' - [%h] %s'
}

$@
