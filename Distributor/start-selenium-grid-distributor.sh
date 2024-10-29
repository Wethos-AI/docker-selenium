#!/usr/bin/env bash

# set -e: exit asap if a command exits with a non-zero status
set -e

echo "Starting Selenium Grid Distributor..."

function append_se_opts() {
  local option="${1}"
  local value="${2:-""}"
  local log_message="${3:-true}"
  if [[ "${SE_OPTS}" != *"${option}"* ]]; then
    if [ "${log_message}" = "true" ]; then
      echo "Appending Selenium option: ${option} ${value}"
    else
      echo "Appending Selenium option: ${option} $(mask "${value}")"
    fi
    SE_OPTS="${SE_OPTS} ${option}"
    if [ -n "${value}" ]; then
      SE_OPTS="${SE_OPTS} ${value}"
    fi
  else
    echo "Selenium option: ${option} already set in env variable SE_OPTS. Ignore new option: ${option} ${value}"
  fi
}

if [[ -z "${SE_EVENT_BUS_HOST}" ]]; then
  echo "SE_EVENT_BUS_HOST not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_EVENT_BUS_PUBLISH_PORT}" ]]; then
  echo "SE_EVENT_BUS_PUBLISH_PORT not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_EVENT_BUS_SUBSCRIBE_PORT}" ]]; then
  echo "SE_EVENT_BUS_SUBSCRIBE_PORT not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_SESSIONS_MAP_HOST}" ]]; then
  echo "SE_SESSIONS_MAP_HOST not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_SESSIONS_MAP_PORT}" ]]; then
  echo "SE_SESSIONS_MAP_PORT not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_SESSION_QUEUE_HOST}" ]]; then
  echo "SE_SESSION_QUEUE_HOST not set, exiting!" 1>&2
  exit 1
fi

if [[ -z "${SE_SESSION_QUEUE_PORT}" ]]; then
  echo "SE_SESSION_QUEUE_PORT not set, exiting!" 1>&2
  exit 1
fi

if [ -n "$SE_OPTS" ]; then
  echo "Appending Selenium options: ${SE_OPTS}"
fi

if [ -n "$SE_DISTRIBUTOR_HOST" ]; then
  echo "Using SE_DISTRIBUTOR_HOST: ${SE_DISTRIBUTOR_HOST}"
  HOST_CONFIG="--host ${SE_DISTRIBUTOR_HOST}"
fi

if [ -n "$SE_DISTRIBUTOR_PORT" ]; then
  echo "Using SE_DISTRIBUTOR_PORT: ${SE_DISTRIBUTOR_PORT}"
  PORT_CONFIG="--port ${SE_DISTRIBUTOR_PORT}"
fi

if [ -n "$SE_LOG_LEVEL" ]; then
  append_se_opts "--log-level" "${SE_LOG_LEVEL}"
fi

if [ -n "$SE_HTTP_LOGS" ]; then
  append_se_opts "--http-logs" "${SE_HTTP_LOGS}"
fi

if [ -n "$SE_STRUCTURED_LOGS" ]; then
  append_se_opts "--structured-logs" "${SE_STRUCTURED_LOGS}"
fi

if [ -n "$SE_EXTERNAL_URL" ]; then
  append_se_opts "--external-url" "${SE_EXTERNAL_URL}"
fi

if [ "${SE_ENABLE_TLS}" = "true" ]; then
  # Configure truststore for the server
  if [ -n "$SE_JAVA_SSL_TRUST_STORE" ]; then
    echo "Appending Java options: -Djavax.net.ssl.trustStore=${SE_JAVA_SSL_TRUST_STORE}"
    SE_JAVA_OPTS="$SE_JAVA_OPTS -Djavax.net.ssl.trustStore=${SE_JAVA_SSL_TRUST_STORE}"
  fi
  if [ -f "${SE_JAVA_SSL_TRUST_STORE_PASSWORD}" ]; then
    echo "Getting Truststore password from ${SE_JAVA_SSL_TRUST_STORE_PASSWORD} to set Java options: -Djavax.net.ssl.trustStorePassword"
    SE_JAVA_SSL_TRUST_STORE_PASSWORD="$(cat "${SE_JAVA_SSL_TRUST_STORE_PASSWORD}")"
  fi
  if [ -n "${SE_JAVA_SSL_TRUST_STORE_PASSWORD}" ]; then
    echo "Appending Java options: -Djavax.net.ssl.trustStorePassword=$(mask "${SE_JAVA_SSL_TRUST_STORE_PASSWORD}")"
    SE_JAVA_OPTS="$SE_JAVA_OPTS -Djavax.net.ssl.trustStorePassword=${SE_JAVA_SSL_TRUST_STORE_PASSWORD}"
  fi
  echo "Appending Java options: -Djdk.internal.httpclient.disableHostnameVerification=${SE_JAVA_DISABLE_HOSTNAME_VERIFICATION}"
  SE_JAVA_OPTS="$SE_JAVA_OPTS -Djdk.internal.httpclient.disableHostnameVerification=${SE_JAVA_DISABLE_HOSTNAME_VERIFICATION}"
  # Configure certificate and private key for component communication
  if [ -n "$SE_HTTPS_CERTIFICATE" ]; then
    append_se_opts "--https-certificate" "${SE_HTTPS_CERTIFICATE}"
  fi
  if [ -n "$SE_HTTPS_PRIVATE_KEY" ]; then
    append_se_opts "--https-private-key" "${SE_HTTPS_PRIVATE_KEY}"
  fi
fi

if [ -n "$SE_REGISTRATION_SECRET" ]; then
  append_se_opts "--registration-secret" "${SE_REGISTRATION_SECRET}" "false"
fi

if [ -n "$SE_REJECT_UNSUPPORTED_CAPS" ]; then
  append_se_opts "--reject-unsupported-caps" "${SE_REJECT_UNSUPPORTED_CAPS}"
fi

if [ -n "$SE_NEW_SESSION_THREAD_POOL_SIZE" ]; then
  append_se_opts "--newsession-threadpool-size" "${SE_NEW_SESSION_THREAD_POOL_SIZE}"
fi

EXTRA_LIBS=""

if [ "$SE_ENABLE_TRACING" = "true" ]; then
  EXTERNAL_JARS=$(</external_jars/.classpath.txt)
  [ -n "$EXTRA_LIBS" ] && [ -n "${EXTERNAL_JARS}" ] && EXTRA_LIBS=${EXTRA_LIBS}:
  EXTRA_LIBS="--ext "${EXTRA_LIBS}${EXTERNAL_JARS}
  echo "Tracing is enabled"
  echo "Classpath will be enriched with these external jars : " "${EXTRA_LIBS}"
  if [ -n "$SE_OTEL_SERVICE_NAME" ]; then
    SE_OTEL_JVM_ARGS="$SE_OTEL_JVM_ARGS -Dotel.resource.attributes=service.name=${SE_OTEL_SERVICE_NAME}"
  fi
  if [ -n "$SE_OTEL_TRACES_EXPORTER" ]; then
    SE_OTEL_JVM_ARGS="$SE_OTEL_JVM_ARGS -Dotel.traces.exporter=${SE_OTEL_TRACES_EXPORTER}"
  fi
  if [ -n "$SE_OTEL_EXPORTER_ENDPOINT" ]; then
    SE_OTEL_JVM_ARGS="$SE_OTEL_JVM_ARGS -Dotel.exporter.otlp.endpoint=${SE_OTEL_EXPORTER_ENDPOINT}"
  fi
  if [ -n "$SE_OTEL_JAVA_GLOBAL_AUTOCONFIGURE_ENABLED" ]; then
    SE_OTEL_JVM_ARGS="$SE_OTEL_JVM_ARGS -Dotel.java.global-autoconfigure.enabled=${SE_OTEL_JAVA_GLOBAL_AUTOCONFIGURE_ENABLED}"
  fi
  if [ -n "$SE_OTEL_JVM_ARGS" ]; then
    echo "List arguments for OpenTelemetry: ${SE_OTEL_JVM_ARGS}"
    SE_JAVA_OPTS="$SE_JAVA_OPTS ${SE_OTEL_JVM_ARGS}"
  fi
else
  append_se_opts "--tracing" "false"
  SE_JAVA_OPTS="$SE_JAVA_OPTS -Dwebdriver.remote.enableTracing=false"
  echo "Tracing is disabled"
fi

java "${JAVA_OPTS:-$SE_JAVA_OPTS}" \
  -jar /opt/selenium/selenium-server.jar \
  "${EXTRA_LIBS}" distributor \
  --sessions-host "${SE_SESSIONS_MAP_HOST}" --sessions-port "${SE_SESSIONS_MAP_PORT}" \
  --sessionqueue-host "${SE_SESSION_QUEUE_HOST}" --sessionqueue-port "${SE_SESSION_QUEUE_PORT}" \
  --publish-events tcp://"${SE_EVENT_BUS_HOST}":"${SE_EVENT_BUS_PUBLISH_PORT}" \
  --subscribe-events tcp://"${SE_EVENT_BUS_HOST}":"${SE_EVENT_BUS_SUBSCRIBE_PORT}" \
  --session-request-timeout "${SE_SESSION_REQUEST_TIMEOUT}" \
  --session-retry-interval "${SE_SESSION_RETRY_INTERVAL}" \
  --healthcheck-interval "${SE_HEALTHCHECK_INTERVAL}" \
  --bind-host "${SE_BIND_HOST}" \
  --bind-bus false \
  "${HOST_CONFIG}" \
  "${PORT_CONFIG}" \
  "${SE_OPTS}"
