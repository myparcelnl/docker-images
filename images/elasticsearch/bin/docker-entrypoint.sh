#!/bin/bash
# bashsupport disable=BP5004

set -e

# Allow user specify custom CMD, maybe bin/elasticsearch itself for example to
# directly specify `-E` style parameters for elasticsearch on k8s or simply to
# run /bin/bash to check the image.
if [[ "${1}" != 'eswrapper' ]]; then
  exec "$@"
fi

# Parse Docker env vars to customize Elasticsearch
#
# e.g. Setting the env var cluster.name=testcluster
#
# will cause Elasticsearch to be invoked with -E cluster.name=testcluster
#
# see https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html#_setting_default_settings

declare -a es_opts

while IFS='=' read -r envvar_key envvar_value; do
  # Elasticsearch settings need to have at least two dot separated lowercase
  # words, e.g. `cluster.name`, except for `processors` which we handle
  # specially
  if [[ "${envvar_key}" =~ ^[a-z0-9_]+\.[a-z0-9_]+ || "${envvar_key}" == "processors" ]]; then
    if [[ -n "${envvar_value}" ]]; then
      es_opt="-E${envvar_key}=${envvar_value}"
      es_opts+=("${es_opt}")
    fi
  fi
done < <(env)

# The virtual file /proc/self/cgroup should list the current cgroup
# membership. For each hierarchy, you can follow the cgroup path from
# this file to the cgroup filesystem (usually /sys/fs/cgroup/) and
# introspect the statistics for the cgroup for the given
# hierarchy. Alas, Docker breaks this by mounting the container
# statistics at the root while leaving the cgroup paths as the actual
# paths. Therefore, Elasticsearch provides a mechanism to override
# reading the cgroup path from /proc/self/cgroup and instead uses the
# cgroup path defined the JVM system property
# es.cgroups.hierarchy.override. Therefore, we set this value here so
# that cgroup statistics are available for the container this process
# will run in.
export ES_JAVA_OPTS="-Des.cgroups.hierarchy.override=/ $ES_JAVA_OPTS"

if [[ -d bin/x-pack ]]; then
  # Check for the ELASTIC_PASSWORD environment variable to set the
  # bootstrap password for Security.
  #
  # This is only required for the first node in a cluster with Security
  # enabled, but we have no way of knowing which node we are yet. We'll just
  # honor the variable if it's present.
  if [[ -n "${ELASTIC_PASSWORD}" ]]; then
    [[ -f /usr/share/elasticsearch/config/elasticsearch.keystore ]] || (elasticsearch-keystore create)
    if ! (elasticsearch-keystore list | grep -q '^bootstrap.password$'); then
      (echo "$ELASTIC_PASSWORD" | elasticsearch-keystore add -x 'bootstrap.password')
    fi
  fi
fi

/usr/share/elasticsearch/bin/elasticsearch "${es_opts[@]}"
