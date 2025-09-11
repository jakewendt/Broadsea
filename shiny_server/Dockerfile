# Base image with R and Shiny Server
FROM rocker/shiny-verse:latest
#FROM rocker/shiny-verse:4.3.0

#	To install R packages, created this Dockerfile
#	EDASeq needed the a newer R

# Install any additional R packages required by your apps
RUN R -e "install.packages('BiocManager');BiocManager::install(); BiocManager::install(c( 'biomaRt', 'conflicted', 'data.table', 'dplyr', 'EDASeq', 'edgeR', 'ggplot2', 'ggrepel', 'grid', 'gridExtra', 'gtable', 'kableExtra', 'pheatmap', 'RColorBrewer', 'readr', 'shinyWidgets', 'tidyr', 'tidyverse') )"

#	set OPEN_SHINY_SERVER_APP_ROOT="./shiny_apps" in .env
#	../shiny_apps/ dir is mounted from docker_compose.yml ${OPEN_SHINY_SERVER_APP_ROOT}
#	so don't need to copy anything
# Copy your Shiny app directories into the container
#COPY ./app1 /srv/shiny-server/app1
#COPY ./app2 /srv/shiny-server/app2

# Configure Shiny Server (optional, if default is not sufficient)
#COPY ./shiny-server.conf /etc/shiny-server/shiny-server.conf

# Expose the port Shiny Server listens on (default is 3838)
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]


#	May want to look into this? Guessing since this is in a container it isn't an issue, however ?
# broadsea-open-shiny-server  | [2025-09-11T00:38:35.519] [INFO] shiny-server - Shiny Server v1.5.24.1034 (Node.js v20.17.0)
# broadsea-open-shiny-server  | [2025-09-11T00:38:35.521] [INFO] shiny-server - Using config file "/etc/shiny-server/shiny-server.conf"
# broadsea-open-shiny-server  | [2025-09-11T00:38:35.559] [WARN] shiny-server - Running as root unnecessarily is a security risk! You could be running more securely as non-root.
# broadsea-open-shiny-server  | [2025-09-11T00:38:35.565] [INFO] shiny-server - Starting listener on http://[::]:3838

#	debugging app failure
#	docker exec 85ad00f45a99 ls -l /var/log/shiny-server/
#	docker exec 85ad00f45a99 cat /var/log/shiny-server/REdiscoverTE_EdgeR-shiny-20250910-222622-43739.log

