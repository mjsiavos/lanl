library(tidyverse)
library(RPostgreSQL)

conn = dbConnect(PostgreSQL(), host='localhost', port=5432, dbname='lanl', user='postgres', password='ti@t$jm4converge2019(@)')

dbListTables(conn)

dbGetQuery(conn, 'select * from auths limit 3')
dbGetQuery(conn, 'select * from ports limit 3')

dbGetQuery(conn, 'select * from ports where name > 65535 limit 3;')
dbGetQuery(conn, "select * from ports where name like 'N%' limit 3;")

dbGetQuery(conn, 'select count(*) from computers;')
dbGetQuery(conn, "select * from user_domains where name like 'U%' limit 3")

dbGetQuery(conn, "select * from flows limit 3")
dbGetQuery(conn, "select src_comp, dest_comp, count(*) from flows group by src_comp, dest_comp order by count(*) desc limit 5")
dbGetQuery(conn, "select * from auths limit 30")
dbGetQuery(conn, "select * from time limit 15")

