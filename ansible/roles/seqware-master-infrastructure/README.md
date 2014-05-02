SeqWare Master Infrastructure Role
----------------------------------

This does setup for a SeqWare master node. This should probably be refactored into smaller roles that do setup for each of the Hadoop components and the shared file system (currently NFS). 

Note that this is the most complicated role, running in two modes (for a single\_node with integrated Hadoop worker daemons and a higher performance master without those daemons). It also provides examples of file provisioning, templating, variables, role dependencies via meta, and handlers. 
