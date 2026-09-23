# Server and environment

## Production computing context

The production workflow was executed on a Slurm-managed Linux HPC system. The archived environment record identifies a CentOS 7 x86_64 compute environment and Conda-based software environments.

Heavy analyses were submitted through Slurm rather than executed interactively on the login/admin node. Stage pages record the formal CPU, memory, wall-time, array, and concurrency settings wherever those values were retained in the production scripts.

## Portable reference scripts

The public scripts intentionally separate analytical parameters from site-specific infrastructure. Variables are used for project roots, reference databases, Conda initialization, manifests, and intermediate/output locations.

Production-site details that are not required for scientific reproducibility are not embedded in the public scripts, including:

- usernames and account identifiers;
- hostnames and IP addresses;
- private storage roots;
- scheduler account/QoS names;
- long-term node exclusion lists;
- temporary transfer URLs or credentials.

This means the scripts require local configuration before use on another cluster, but the biological and algorithmic parameters remain unchanged.

## Environment provenance

Verified software versions and reference-database releases are maintained on the [Software and databases](software-and-databases.md) page. Some helper-tool versions were not retained in the archived environment snapshot; these are explicitly marked as not captured rather than inferred.

The repository does not distribute Conda environments or large reference databases. Users should create environments that provide the documented tool versions and configure database paths through the variables used by the reference scripts.

## Scheduler portability

The retained Slurm resource requests document the production scale of each step. Site-specific directives can be adapted for another cluster, but changing CPU or memory settings may require corresponding changes to tool thread arguments when those are tied to \`SLURM_CPUS_PER_TASK\`.

For stages where a formal Slurm wrapper was not retained, the repository does not invent one.
