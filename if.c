#include "if.h"

#include "config.h"

#include "libks/arena.h"

#ifdef __OpenBSD__

#include <sys/types.h>
#include <sys/ioctl.h>
#include <sys/socket.h>

#include <arpa/inet.h>
#include <err.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const void *
socket_addr(const struct sockaddr *sa, sa_family_t family)
{
	switch (family) {
	case AF_INET:
		return &((const struct sockaddr_in *)sa)->sin_addr;
	case AF_INET6:
		return &((const struct sockaddr_in6 *)sa)->sin6_addr;
	}
	return NULL;
}

/*
 * Get the first address associated with the given interface group and address
 * family.
 */
const char *
if_group_addr(const char *group, int family, struct arena_scope *s)
{
	struct ifgroupreq ifgr;
	struct ifaddrs *ifap = NULL;
	struct ifaddrs *ifa;
	const char *iface;
	char *inet = NULL;
	size_t inetsiz = 64;
	sa_family_t sa_family = AF_UNSPEC;
	int sock;

	if (family == 4)
		sa_family = AF_INET;
	else if (family == 6)
		sa_family = AF_INET6;
	else
		return NULL;

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
	ifgr.ifgr_groups = arena_calloc(s, 1, ifgr.ifgr_len);
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
		const struct sockaddr *sa;

		if (ifa->ifa_addr == NULL ||
		    ifa->ifa_addr->sa_family != sa_family ||
		    strcmp(ifa->ifa_name, iface) != 0)
			continue;

		sa = ifa->ifa_addr;
		inet = arena_calloc(s, 1, inetsiz);
		if (inet_ntop(sa_family, socket_addr(sa, sa_family),
		    inet, inetsiz) == NULL) {
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

#include "libks/compiler.h"

const char *
if_group_addr(const char *group, int UNUSED(family), struct arena_scope *s)
{
	return arena_strdup(s, group);
}

#endif
