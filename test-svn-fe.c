/*
 * test-svn-fe: Code to exercise the svn import lib
 */

#include "git-compat-util.h"
#include "vcs-svn/svndump.h"
#include "vcs-svn/svndiff.h"
#include "vcs-svn/line_buffer.h"

int main(int argc, char *argv[])
{
	static const char test_svnfe_usage[] =
		"test-svn-fe (<dumpfile> | [-d] <preimage> <delta> <len>)";
	if (argc < 2)
		usage(test_svnfe_usage);
	if (argc == 2) {
		svndump_init(argv[1]);
		svndump_read(NULL);
		svndump_deinit();
		svndump_reset();
		return 0;
	}
	if (argc == 5 && !strcmp(argv[1], "-d")) {
		struct line_buffer preimage = LINE_BUFFER_INIT;
		struct line_buffer delta = LINE_BUFFER_INIT;
		if (buffer_init(&preimage, argv[2]))
			die_errno("cannot open preimage");
		if (buffer_init(&delta, argv[3]))
			die_errno("cannot open delta");
		if (svndiff0_apply(&delta, (off_t) strtoull(argv[4], NULL, 0),
				   &preimage, stdout))
			return 1;
		if (buffer_deinit(&preimage))
			die_errno("cannot close preimage");
		if (buffer_deinit(&delta))
			die_errno("cannot close delta");
		buffer_reset(&preimage);
		buffer_reset(&delta);
		return 0;
	}
	usage(test_svnfe_usage);
}
