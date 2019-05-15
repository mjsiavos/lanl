library(igraph)
library(ggraph)
library(graphlayouts)
library(tidyverse)
library(RPostgreSQL)

conn = dbConnect(PostgreSQL(), dbname='lanl', host='localhost', port=5432, 
                 user='potentpwnables', password='converge2019')

query = function(conn, query) {
    return(tbl_df(dbGetQuery(conn, query)))
}

# Let's try to identify the domain controllers using a graph
el = query(conn, 'select source, target, weight from auth_el')
el = el %>%
    mutate(as.character(source),
           as.character(target))
tmp = el[el$source == 1, ]
ggplot(el, aes(x=source, y=target, fill=weight)) +
    geom_tile() +
    theme(panel.background=element_blank())

nodes = tibble(name=unique(c(el$source, el$target)))
sizes = el %>%
    group_by(target) %>%
    summarise(size = length(unique(source))) %>%
    ungroup()
nodes = nodes %>%
    left_join(sizes, by=c('name'='target')) %>%
    mutate(size = ifelse(is.na(size), 0, size))
g = graph_from_data_frame(el, directed=T, vertices=nodes)

p = ggraph(g, layout='nicely') +
    geom_node_point() +
    geom_edge_link() +
    theme_graph()

flow = dbGetQuery(conn, 'select * from flow_el') %>%
    tbl_df()
g2 = graph_from_data_frame(flow, directed=TRUE)
ggraph(g2) +
    geom_node_point(size=0.6) +
    theme_graph()
