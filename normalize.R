# This script takes the raw data from http://csr.lanl.gov/data/cyber1
# and replaces the categorical values with their integer equivalents
# using the lookup tables created by the shell scripts.

library(tidyverse)
library(RPostgreSQL)

split_file = function(fname, prefix, size='5120M') {
    # Split the file
    cmd = paste('cd data && split -C', size, fname, prefix)
    system(cmd)
    return(NULL)
}

# Read in reference files
computers = read_csv('data/computers.csv', col_types='ic')
user_domains = read_csv('data/user_domains.csv', col_types='ic')
ports = read_csv('data/ports.csv', col_types='ic')
processes = read_csv('data/processes.csv', col_types='ic')
auth_type = read_csv('data/auth_type.csv', col_types='ic')
logon_type = read_csv('data/logon_type.csv', col_types='ic')
auth_orientation = read_csv('data/auth_orientation.csv', col_types='ic')

process_reference_tables = function(con) {
    dbWriteTable(con, 'computers', computers, append=T, row.names=F)
    dbWriteTable(con, 'user_domains', user_domains, append=T, row.names=F)
    dbWriteTable(con, 'ports', ports, append=T, row.names=F)
    dbWriteTable(con, 'processes', processes, append=T, row.names=F)
    dbWriteTable(con, 'auth_type', auth_type, append=T, row.names=F)
    dbWriteTable(con, 'logon_type', logon_type, append=T, row.names=F)
    dbWriteTable(con, 'auth_orientation', auth_orientation, append=T, row.names=F)
    print("Reference tables successfully saved to database")
}

process_auth = function(con) {
    # auth.txt is 69GB, so we'll split the file into 14 5GB files and process
    # those in order to be able to do the processing in R
    print('Processing AUTH...')
    split_file('auth.txt', prefix='auth_')
    for (f in list.files('data/', pattern='auth_a[a-z]', full.names=TRUE)) {
        df = read_csv(f, col_names=c('time', 'src_user_domain', 'dest_user_domain',
                                     'src_comp', 'dest_comp', 'auth_type', 'logon_type',
                                     'auth_orientation', 'success'))
        
        df = df %>%
            left_join(user_domains, by=c('src_user_domain'='name')) %>%
            select(-src_user_domain) %>%
            rename(src_user_domain=id) %>%
            left_join(user_domains, by=c('dest_user_domain'='name')) %>%
            select(-dest_user_domain) %>%
            rename(dest_user_domain=id) %>%
            left_join(computers, by=c('src_comp'='name')) %>%
            select(-src_comp) %>%
            rename(src_comp=id) %>%
            left_join(computers, by=c('dest_comp'='name')) %>%
            select(-dest_comp) %>%
            rename(dest_comp=id) %>%
            left_join(auth_type, by=c('auth_type'='name')) %>%
            select(-auth_type) %>%
            rename(auth_type=id) %>%
            left_join(logon_type, by=c('logon_type'='name')) %>%
            select(-logon_type) %>%
            rename(logon_type=id) %>%
            left_join(auth_orientation, by=c('auth_orientation'='name')) %>%
            select(-auth_orientation) %>%
            rename(auth_orientation=id) %>%
            mutate(success = as.integer(success == 'Success'))
        
        dbWriteTable(con, 'auths', df, append=T, row.names=F)
        
        # Cleanup
        rm(df)
        unlink(f)
    }
    print('AUTH successfully processed...')
}

process_flows = function(con) {
    # flows.txt is 5GB, which is kind of big, but we'll just read it in
    print('Processing FLOWS...')
    flows = read_csv('data/flows.txt', 
                     col_names=c('time', 'duration', 'src_comp', 'src_port',
                                 'dest_comp', 'dest_port', 'protocol', 
                                 'packet_count', 'byte_count'),
                     col_types=c('iiccccidd'))
    
    flows = flows %>%
        left_join(computers, by=c('src_comp'='name')) %>%
        select(-src_comp) %>%
        rename(src_comp=id) %>%
        left_join(computers, by=c('dest_comp'='name')) %>%
        select(-dest_comp) %>%
        rename(dest_comp=id) %>%
        left_join(ports, by=c('src_port'='name')) %>%
        select(-src_port) %>%
        rename(src_port=id) %>%
        left_join(ports, by=c('dest_port'='name')) %>%
        select(-dest_port) %>%
        rename(dest_port=id)
    
    dbWriteTable(con, 'flows', flows, append=T, row.names=F)
    print('FLOWS processed successfully...')
}

process_proc = function(con) {
    # proc.txt is 15GB, so to make it more manageable, we'll split
    # the file into 3 5GB files and iterate through them.
    print('Processing PROC...')
    split_file('proc.txt', 'proc_')
    
    for (f in list.files('data/', pattern='proc_a[a-z]', full.names=TRUE)) {
        df = read_csv(f, col_names=c('time', 'user_domain', 'computer', 
                                     'process', 'start'),
                      col_types=c('icccc'))
        
        df = df %>%
            left_join(user_domains, by=c('user_domain'='name')) %>%
            select(-user_domain) %>%
            rename(user_domain=id) %>%
            left_join(computers, by=c('computer'='name')) %>%
            select(-computer) %>%
            rename(computer=id) %>%
            left_join(processes, by=c('process'='name')) %>%
            select(-process) %>%
            rename(process=id) %>%
            mutate(start = as.integer(start == 'Start'))
        
        out = 'data/proc.csv'
        if (file.exists(out)) {
            cnames = FALSE
        } else {
            cnames = TRUE
        }
        dbWriteTable(con, 'procs', df, append=T, row.names=F)
        
        # Cleanup
        rm(df)
        for (i in 1:10) gc()
        system(paste('rm', f))
    }
    
    print('PROC processed successfully...')
}

process_dns = function(con) {
    print('Processing DNS...')
    dns = read_csv('data/dns.txt', col_names=c('time', 'src_comp', 'rslvd_comp'), col_types=c('icc'))
    
    dns = dns %>%
        left_join(computers, by=c('src_comp'='name')) %>%
        select(-src_comp) %>%
        rename(src_comp = id) %>%
        left_join(computers, by=c('rslvd_comp'='name')) %>%
        select(-rslvd_comp) %>%
        rename(rslvd_comp = id)
    
    dbWriteTable(con, 'dns', dns, append=T, row.names=F)
    print('DNS processed successfully...')
}

process_redteam = function(con) {
    print('Processing REDTEAM...')
    redteam = read_csv('data/redteam.txt', 
                       col_names=c('time', 'user_domain', 'src_comp', 'dest_comp'),
                       col_types=c('iccc'))
    
    redteam = redteam %>%
        left_join(user_domains, by=c('user_domain'='name')) %>%
        select(-user_domain) %>%
        rename(user_domain = id) %>%
        left_join(computers, by=c('src_comp'='name')) %>%
        select(-src_comp) %>%
        rename(src_comp = id) %>%
        left_join(computers, by=c('dest_comp'='name')) %>%
        select(-dest_comp) %>%
        rename(dest_comp = id)
    
    dbWriteTable(con, 'redteam', redteam, append=T, row.names=F)
    print('REDTEAM processed successfully...')
}

create_time_table = function(con) {
    print('Creating TIME...')
    time = tibble(t_second=1:5184000)
    time = time %>%
        mutate(t_minute = (t_second - (t_second %% -60)) / 60,
               t_hour = (t_second - (t_second %% -3600)) / 3600,
               day = (t_second - (t_second %% -86400)) / 86400,
               d_second = t_second - (86400 * (day - 1)),
               d_minute = t_minute - (1440 * (day - 1)),
               d_hour = t_hour - (24 * (day - 1))) %>%
        mutate_all(as.integer) %>%
        mutate(tmp_second = (d_second - (60 * (d_minute - 1))) - 1, 
               tmp_minute = (d_minute - (60 * (d_hour - 1))) - 1,
               date = paste0("Day ", str_pad(day, width=2, side='left', pad='0'), " ", 
                             str_pad(d_hour-1, width=2, side='left', pad='0'), ":", 
                             str_pad(tmp_minute, width=2, side='left', pad='0'), ":", 
                             str_pad(tmp_second, width=2, side='left', pad='0'))) %>%
        select(-tmp_minute, -tmp_second)
    dbWriteTable(con, 'time', time, append=T, row.names=F)
    print('TIME processed successfully...')
}

main = function() {
    con = DBI::dbConnect(PostgreSQL(), dbname='lanl', host='localhost', port=5432, 
                         user='potentpwnables', password='converge2019')
    
    process_reference_tables(con)
    process_dns(con)
    process_redteam(con)
    process_flows(con)
    process_proc(con)
    process_auth(con)
    create_time_table(con)
}