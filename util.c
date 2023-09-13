#include "util.h"

#include "config.h"

#include "alloc.h"

#ifdef __OpenBSD__

#include <sys/types.h>
#include <sys/ioctl.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <netinet/in.h>
#include <ifaddrs.h>

#include <err.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/*
 * Get the first IPv4 address associated with the given interface group.
 */
char *
ifgrinet(const char *group)
{
	struct ifgroupreq ifgr;
	struct ifaddrs *ifap = NULL;
	struct ifaddrs *ifa;
	const char *iface;
	char *inet = NULL;
	size_t inetsiz = 16;
	int sock;

	sock = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, 0);
	if (sock == -1) {
		warn("socket");
		return NULL;
	}

	memset(&ifgr, 0, sizeof(ifgr));
	strlcpy(ifgr.ifgr_name, group, IFNAMSIZ);
	if (ioctl(sock, SIOCGIFGMEMB, &ifgr) == -1) {
		warn("ioctl: SIOCGIFGMEMB");
		goto out;
	}
	if (ifgr.ifgr_len == 0) {
		warnx("interface group '%s' is empty", group);
		goto out;
	}
	ifgr.ifgr_groups = ecalloc(1, ifgr.ifgr_len);
	if (ioctl(sock, SIOCGIFGMEMB, &ifgr) == -1) {
		warn("ioctl: SIOCGIFGMEMB");
		goto out;
	}
	iface = ifgr.ifgr_groups[0].ifgrq_member;

	if (getifaddrs(&ifap) == -1) {
		warn("getifaddrs");
		goto out;
	}
	for (ifa = ifap; ifa != NULL; ifa = ifa->ifa_next) {
		const struct sockaddr_in *sin;

		if (ifa->ifa_addr == NULL ||
		    ifa->ifa_addr->sa_family != AF_INET ||
		    strcmp(ifa->ifa_name, iface) != 0)
			continue;

		sin = (struct sockaddr_in *)ifa->ifa_addr;
		inet = ecalloc(1, inetsiz);
		if (inet_ntop(AF_INET, &sin->sin_addr, inet, inetsiz) == NULL) {
			warn("inet_ntop");
			goto out;
		}
		break;
	}

out:
	freeifaddrs(ifap);
	close(sock);
	return inet;
}

#else

char *
ifgrinet(const char *group)
{
	return estrdup(group);
}

#endif
