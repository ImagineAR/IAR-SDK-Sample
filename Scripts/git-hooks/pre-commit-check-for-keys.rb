#!/usr/bin/env ruby

# This script can be bypassed by using the --no-verify
# parameter when checking in

files_modified = `git diff-index --cached --name-only HEAD`

files_modified_arr = files_modified.split("\n")

puts "Checking files: #{files_modified_arr.inspect}"

bad_files = 0

# Build a hash of all the keys and things you don't want
# checked in here.
# Note the pair of slashes before the slash quote, this
# is to ensure a slash quote is built into the string
# to be passed to grep.

regexs = {
    "AWS Key" => "['\\\"][a-z0-9\/+]{40}['\\\"]",
    "Google Key" => "['\\\"][a-z0-9_]{39}['\\\"]",
    "IAR Org Key" => "pk_[a-z0-9_]{36}",
}

files_modified_arr.each do |file|
    regexs.each_pair do |key_name, regex|
        grep_command = "grep -iE \"#{regex}\" #{file}"
        res = `#{grep_command}`
        unless res == ""
            bad_files += 1
            puts "Failed to commit: [Key Leak] Matching rule for #{key_name} on file: #{file}"
        end
    end
end

exit bad_files
