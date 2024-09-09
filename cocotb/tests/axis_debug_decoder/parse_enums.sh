#!/usr/bin/env bash


#Requires ripgrep (rg)

header_file=$(ack -l "ENUMS \(that were declared public\)")
echo $header_file
rg "enum .*__DOT__(.*_t)" -or '$1' $header_file | while read enum_def; do
    echo "Parsing $enum_def"
    rg -U "^.*enum .*__DOT__$enum_def \{(([A-Z_ =0-9,]*\n)*).*\};.*$" -or '$1' $header_file > "${enum_def}.enum"
done

