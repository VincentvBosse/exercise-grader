# Grader image - deadline testing & reporting.
#
# Derives from codeberg.org/hopper/grader-base:latest (shared framework).
# This Dockerfile adds only the stage config, task tests, and a demo
# workspace - no run.py, testrunner.py, or schema duplication.
#
# Self-contained, stateless, no network. Runs as the non-root user
# inherited from the base image (UID/GID 1000). The submission is expected
# at /workspace/<EXERCISE> (baked-in examples provided for demonstration;
# mount a real submission to override).
FROM codeberg.org/hopper/grader-base:latest

# Stage config and bundled task tests (owned by root, readable by all).
USER root
COPY config.yaml /opt/grader-base/config.yaml
COPY tasks/ /opt/grader-base/tasks/

# Task structure manifest for the build service (README contract, see
# docs/build.md in the platform monorepo). Owned by root, readable by all.
COPY manifest.yaml /hopper/manifest.yaml

# Bake a minimal example workspace so the image is demoable without a
# volume mount. A bind mount over /workspace overrides it for real runs.
COPY workspace/ /workspace/

# Make the example workspace readable and traversable by the non-root user.
RUN chmod -R a+rX /opt/grader-base/tasks /workspace \
    && find /opt/grader-base/tasks /workspace -type d -exec chmod a+rx {} +

# ENTRYPOINT is inherited from codeberg.org/hopper/grader-base:latest.
USER runner
