#Shared Host Integrated Password System
Copyright 2015 Shared Host Integrated Password System (SHIPS)

Written by: Geoff Walton at TrustedSec

Company: [TrustedSec](https://www.trustedsec.com)

Please read the design and installation documentation located in the doc/ folder.

#What IS SHIPS?

The Shared Host Integrated Password System (SHIPS) is a solution to provide unique and rotated local super user or administrator passwords for environments where it is not possible or not appropriate to disable these local accounts. Clients may be configured to rotate passwords automatically. Stored passwords can be retrieved by desktop support personnel as required, or updated when a password has to be manually changed in the course of system maintenance. By having unique passwords on each machine and logging of password retrievals, security can be improved by making networks more resistant to lateral movement by attackers and enhancing the ability to attribute actions to individual persons.

When performing penetration tests, our common attack vector is through compromising one host and pivoting to other systems with the information obtained. It is common to see large-scale breaches utilizing this method and that is where SHIPS comes into play.

SHIPS is designed to make post-exploitation more difficult and minimize what systems attackers gain access to. Once SHIPS is set up, there isn’t much else that is needed and it’s simple to integrate into existing business processes.

# How it works..

A script is deployed to the endpoints, servers, and any other systems through group policy or similar deployment tools. The script is run on a determined timeframe from the organization. The script makes a password request to the server, which generates unique password string that it stores and transmits to the client. The client script than applies the new password on the client. TrustedSec recommends deploying SHIPS to servers, workstations, or any other windows-based systems. The passwords will now be unique per individual server and workstation.
For organizations where client and server support roles are segregated to different groups of employees, multiple instances of the SHIPS server can be run on a single host. Simply change the listing port on one of server instances and configure each to authorize the appropriate users. TrustedSec recommends using the alternate listening port for the instance supporting server infrastructure. In most cases accommodating requests on the alternate port from servers will be easier than frequently more mobile clients, with regard to firewalls or proxies.

When users with permission to access account passwords wish to retrieve them, they simply log into the SHIPS admin server and do a lookup of the machine name. The web application will display the current password associated with the device. SHIPS authorization can be tied to external systems such as LDAP.

### 

For bug reports or enhancements, please open an issue here https://github.com/trustedsec/SHIPS/issues

### Supported platforms

- Designed for Linux and OSX 
- Also works with Windows
