#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#include "khlib_log.h"
#include "khlib_time.h"

#define usage(...) {print_usage(); fprintf(stderr, "Error:\n    " __VA_ARGS__); exit(EXIT_FAILURE);}

#define MAX_LEN 20
#define END_OF_MESSAGE '\n'

char *argv0 = NULL;

double opt_interval = 1.0;
char *opt_fmt = "%a %b %d %H:%M:%S";

void
print_usage()
{
	printf(
	    "%s: [OPT ...]\n"
	    "\n"
	    "OPT = -i int     # interval\n"
	    "    | -f string  # format string\n"
	    "    | -h         # help message (i.e. what you're reading now :) )\n",
	    argv0);
}

void
opt_parse(int argc, char **argv)
{
	char c;

	while ((c = getopt(argc, argv, "f:i:h")) != -1)
		switch (c) {
		case 'f':
			opt_fmt = calloc(strlen(optarg), sizeof(char));
			strcpy(opt_fmt, optarg);
			break;
		case 'i':
			opt_interval = atof(optarg);
			break;
		case 'h':
			print_usage();
			exit(EXIT_SUCCESS);
		case '?':
			if (optopt == 'f' || optopt == 'i')
				fprintf(stderr,
					"Option -%c requires an argument.\n",
					optopt);
			else if (isprint(optopt))
				fprintf (stderr,
					"Unknown option `-%c'.\n",
					optopt);
			else
				fprintf(stderr,
					"Unknown option character `\\x%x'.\n",
					optopt);
			exit(EXIT_FAILURE);
		default:
			assert(0);
		}
}

int
main(int argc, char **argv)
{
	argv0 = argv[0];

	time_t t;
	struct timespec ti;
	char buf[MAX_LEN];

	opt_parse(argc, argv);
	ti = khlib_timespec_of_float(opt_interval);
	khlib_debug("opt_fmt: \"%s\"\n", opt_fmt);
	khlib_debug("opt_interval: %f\n", opt_interval);
	khlib_debug("ti: {tv_sec = %ld, tv_nsec = %ld}\n",ti.tv_sec,ti.tv_nsec);
	memset(buf, '\0', MAX_LEN);
	signal(SIGPIPE, SIG_IGN);

	for (;;) {
		t = time(NULL);
		strftime(buf, MAX_LEN, opt_fmt, localtime(&t));
		puts(buf);
		fflush(stdout);
		khlib_sleep(&ti);
	}
	return EXIT_SUCCESS;
}
