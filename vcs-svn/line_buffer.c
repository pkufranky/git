/*
 * Licensed under a two-clause BSD-style license.
 * See LICENSE for details.
 */

#include "git-compat-util.h"
#include "line_buffer.h"
#include "strbuf.h"

#define COPY_BUFFER_LEN 4096

int buffer_init(struct line_buffer *buf, const char *filename)
{
	buf->infile = filename ? fopen(filename, "r") : stdin;
	if (!buf->infile)
		return -1;
	return 0;
}

int buffer_deinit(struct line_buffer *buf)
{
	int err;
	if (buf->infile == stdin)
		return ferror(buf->infile);
	err = ferror(buf->infile);
	err |= fclose(buf->infile);
	return err;
}

int buffer_ferror(struct line_buffer *buf)
{
	return ferror(buf->infile);
}

int buffer_at_eof(struct line_buffer *buf)
{
	int ch;
	if ((ch = fgetc(buf->infile)) == EOF)
		return 1;
	if (ungetc(ch, buf->infile) == EOF)
		return error("cannot unget %c: %s\n", ch, strerror(errno));
	return 0;
}

int buffer_read_char(struct line_buffer *buf)
{
	return fgetc(buf->infile);
}

/* Read a line without trailing newline. */
char *buffer_read_line(struct line_buffer *buf)
{
	char *end;
	if (!fgets(buf->line_buffer, sizeof(buf->line_buffer), buf->infile))
		/* Error or data exhausted. */
		return NULL;
	end = buf->line_buffer + strlen(buf->line_buffer);
	if (end[-1] == '\n')
		end[-1] = '\0';
	else if (feof(buf->infile))
		; /* No newline at end of file.  That's fine. */
	else
		/*
		 * Line was too long.
		 * There is probably a saner way to deal with this,
		 * but for now let's return an error.
		 */
		return NULL;
	return buf->line_buffer;
}

char *buffer_read_string(struct line_buffer *buf, uint32_t len)
{
	strbuf_reset(&buf->blob_buffer);
	strbuf_fread(&buf->blob_buffer, len, buf->infile);
	return ferror(buf->infile) ? NULL : buf->blob_buffer.buf;
}

void buffer_read_binary(struct strbuf *sb, uint32_t size,
			struct line_buffer *buf)
{
	strbuf_fread(sb, size, buf->infile);
}

void buffer_copy_bytes(struct line_buffer *buf, FILE *outfile, off_t len)
{
	char byte_buffer[COPY_BUFFER_LEN];
	uint32_t in;
	while (len > 0 && !feof(buf->infile) && !ferror(buf->infile)) {
		in = len < COPY_BUFFER_LEN ? len : COPY_BUFFER_LEN;
		in = fread(byte_buffer, 1, in, buf->infile);
		len -= in;
		fwrite(byte_buffer, 1, in, outfile);
		if (ferror(outfile)) {
			buffer_skip_bytes(buf, len);
			return;
		}
	}
}

off_t buffer_skip_bytes(struct line_buffer *buf, off_t nbytes)
{
	off_t done = 0;
	while (done < nbytes && !feof(buf->infile) && !ferror(buf->infile)) {
		char byte_buffer[COPY_BUFFER_LEN];
		off_t len = nbytes - done;
		uint32_t in = len < COPY_BUFFER_LEN ? len : COPY_BUFFER_LEN;
		done += fread(byte_buffer, 1, in, buf->infile);
	}
	return done;
}

void buffer_reset(struct line_buffer *buf)
{
	strbuf_release(&buf->blob_buffer);
}
