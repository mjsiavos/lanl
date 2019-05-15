library(tidyverse)
library(ggrepel)
library(RPostgreSQL)

conn = dbConnect(PostgreSQL(), dbname='lanl', host='localhost', port=5432, 
                user='potentpwnables', password='converge2019')

query = function(conn, query) {
    return(tbl_df(dbGetQuery(conn, query)))
}

# Get activity by day
q = "
SELECT t.day AS day, count(*) as n
FROM (
    SELECT time FROM auths
) a
LEFT JOIN time t ON a.time = t.t_second
GROUP BY t.day
"
cnt_by_day = query(conn, q)

ggplot(cnt_by_day, aes(x=day, y=n/1e6)) +
    geom_line() +
    geom_point() +
    scale_y_continuous(breaks=seq(10,30), labels=seq(10,30), limits=c(10,30), expand=c(0,0)) +
    scale_x_continuous(breaks=seq(1,59, by=2), labels=seq(1,59,by=2), limits=c(1,59)) +
    labs(x="Day", y="Authorizations (in millions)") +
    theme(panel.background=element_blank(),
          panel.grid.major=element_line(color='gray90'),
          axis.line=element_line(color="black"))

# Day 1 appears to be a Wednesday, so let's map out all of the days
days = c('Wed', 'Thur', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue')
idx = rep(1:7, times=9)
idx = idx[1:nrow(cnt_by_day)]
labels = days[idx]
ggplot(cnt_by_day, aes(x=day, y=n/1e6)) +
    geom_line() +
    geom_point() +
    scale_y_continuous(breaks=seq(10,26), labels=seq(10,26), limits=c(10,26), expand=c(0,0)) +
    scale_x_continuous(breaks=seq(1,58), labels=labels, limits=c(1,58), expand=c(0,1)) +
    labs(x="Day", y="Authorizations (in millions)") +
    theme(panel.background=element_blank(),
          panel.grid.major=element_line(color='gray90'),
          axis.line=element_line(color="black"),
          axis.text.x=element_text(angle=45, hjust=1))

# Let's try to make sense of the auth table

# How many of each type of logon event is there?
q = "
select b.name, a.count
from (
    select logon_type, count(*)
    from auths
    group by logon_type
) a
left join logon_type b on a.logon_type = b.name
order by a.count desc
"
results = query(conn, q)

# See if we can identify computers most likely to be domain controllers
el = query(conn, 'select source, target, weight from auth_el')
pdata = el %>%
    group_by(target) %>%
    summarise(size=length(unique(source)),
              conns=sum(weight)) %>%
    ungroup() %>%
    mutate(size = (size - min(size)) / (max(size) - min(size)),
           label = ifelse(conns >= 5e7, as.character(target), ''))

ggplot(data=pdata, aes(x=target, y=log(conns, base=10), size=size)) +
    geom_point(alpha=0.1) +
    geom_text_repel(label=pdata$label, size=3) +
    labs(x="Destination Computer", 
         y="Number of Connections", 
         title="Size represents number of unique computers connecting to that computer") +
    theme(panel.background=element_blank(),
          axis.line=element_line(color='black'),
          axis.text.x=element_blank(),
          axis.ticks.x=element_blank(),
          legend.position='none')

# Can we confirm that? We know that Kerberos listens on UDP port 88
q = "
select dest_comp, count(*) 
from flows where dest_port in (select id from ports where name='88')
group by dest_comp
order by count(*) desc
limit 20;
"
results = query(conn, q)

# Is there a correlation between the number of computers that connect to the domain and the number of connections?
ggplot(data=pdata, aes(x=size, y=log(conns, base=10))) +
    geom_point() +
    theme(panel.background=element_blank(),
          axis.line=element_line(color='black'),
          legend.position='none')
# very faint



# Look at bytes for ssh flows
query = '
select a.time, b.date, round(avg(a.byte_count), 2) as avg_bytes 
from flows a
left join time b on a.time = b.t_second
where dest_port = 110 
group by a.time, b.date
'
bytes = tbl_df(dbGetQuery(conn, query))
ggplot(bytes, aes(date, avg_bytes)) +
    geom_bar(stat='identity') +
    theme(panel.background=element_blank(),
          panel.grid.major=element_line(color='gray90'),
          axis.line=element_line(color="black"),
          axis.text.x=element_text(angle=45, hjust=1))

# look at logon times
query = "
select b.date, count(*) as n
from auths a 
left join time b 
    on a.time = b.t_second 
where auth_orientation=3 
group by b.date;
"
logons = tbl_df(dbGetQuery(conn, query))
logons$hour = str_extract(logons$date, "(?<=\\s)\\d{2}(?=:)")
logons$day = str_extract(logons$date, "(?<=Day )\\d{2}")

logons %>%
    filter(count < 500) %>%
    ggplot(aes(hour, count)) +
        geom_boxplot() +
        theme(panel.background=element_blank(),
              panel.grid.major=element_line(color='gray90'),
              axis.line=element_line(color="black"))

logons %>%
    group_by(day) %>%
    summarize(count = sum(count)) %>% 
    ungroup() %>%
    ggplot(aes(day, count)) +
    geom_point() +
    theme(panel.background=element_blank(),
          panel.grid.major=element_line(color='gray90'),
          axis.line=element_line(color="black"))
