#!/bin/bash

zig -femit-docs --output-dir zig-cache/ test src/lib.zig && \
	mv zig-cache/docs .
