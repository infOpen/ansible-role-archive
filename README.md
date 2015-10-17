archive-files
=============

[![Build Status](https://travis-ci.org/infOpen/ansible-role-archive-files.svg?branch=master)](https://travis-ci.org/infOpen/ansible-role-archive-files)

Install archive-files backup script.

Requirements
------------

This role requires Ansible 1.4 or higher, and platform requirements are listed
in the metadata file.

Role Variables
--------------

Follow the possible variables with their default values

    # Defaults file for archive-files

    # Common settings
    archive_files_script_destination : "/root/scripts"
    archive_files_script_mode        : "0700"
    archive_files_script_owner       : "root"
    archive_files_script_group       : "root"

    # Tasks
    archive_files_tasks : []

    # Task definition example :
    # - cronfile : "foo"
    #   cron :
    #     user      : "root"
    #     minute    : 0
    #     hour      : 23
    #     month_day : "*"
    #     month     : "*"
    #     week_day  : "*"
    #   backup_directory : ""
    #   sql  :
    #     do_mysql_backup  : False
    #     mysql_databases  : []
    #   files :
    #     do_recursive_backup : False
    #     files_list          : []
    #   logging :
    #     main_log_file  : ""
    #     error_log_file : ""
    #   ssh :
    #     remote_username  : ""
    #     remote_host      : ""
    #     remote_directory : ""
    #     remote_script    : ""


Dependencies
------------

None

Example Playbook
----------------

    - hosts: servers
      roles:
         - { role: achaussier.archive-files }

License
-------

MIT

Author Information
------------------

Alexandre Chaussier (for Infopen company)
- http://www.infopen.pro
- a.chaussier [at] infopen.pro
