#Shared Host Integrated Password System
Copyright 2016 Shared Host Integrated Password System (SHIPS)

Written by: Geoff Walton at TrustedSec

Company: [TrustedSec](https://www.trustedsec.com)

Please read the design and installation documentation located in the doc/ folder.

#What IS SHIPS?

SHIPS is a solution to provide unique and rotated local super user or administrator passwords for environments where it is not possible or not appropriate to disable these local accounts. SHIPS also attempts to address secure sharing of these accounts when they must be controlled by multiple parties. Client systems may be configured to rotate passwords automatically. Stored passwords can be retrieved by desktop support personnel as required, or updated when a password has to be manually changed in the course of system maintenance. By having unique passwords on each machine and logging of password retrievals, security can be improved by making networks more resistant to lateral movement by attackers and enhancing the ability to attribute actions to individual persons.

When performing penetration tests, our common attack vector is through compromising one host and pivoting to other systems with the information obtained. It is common to see large-scale breaches utilizing this method and that is where SHIPS comes into play.

SHIPS is designed to make post-exploitation more difficult and minimize what systems attackers gain access to. Once SHIPS is set up, there isn’t much else that is needed and it’s simple to integrate into existing business processes.

## ProjectGoals 

A complete solution packaged as a single application which can be deployed on a variety of platforms.

Deployments should be simple to move or relocate (this may be required in disaster recovery situations).

Immediately useable with little or no training for support personnel.

Low resource consumption on server and clients.

Low impact on WANs.

Support a wide variety of clients.

Simple client protocol so various operating systems and devices can be integrated with the server through shell scripts and utilities such as cURL.

Simple to integrate with external directories or asset management tools.

Ability to easily script interaction with the server in order to facilitate system
deployment processes, or integrate with other support tools.

### 

For bug reports or enhancements, please open an issue here https://github.com/trustedsec/SHIPS/issues

### Supported Server Platforms

- Designed for Linux and OSX 
- Also works with Windows

### Supported Client Platforms

- Microsoft Windows (all versions)
- Most Linux Distributions
