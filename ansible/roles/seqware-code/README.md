SeqWare Code Role 
------------------

This sets up SeqWare's jar distributions and supporting files.
This can be run in one of two ways, either by deploying built artifacts from artifactory using a git "skeleton" checkout of SeqWare or by building SeqWare from source. 

Note that this has seqware-master-infrastructure as a dependency since it assumes that the SeqWare user and home directory has been properly setup. This also provides overrideable default variables for the repo version and build commands. 
