# Rename the top cell of a GDS layout in place.
#   klayout -zz -r rename_top_cell.rb -rd input=in.gds -rd output=out.gds -rd newname=NAME
ly = RBA::Layout::new()
ly.read($input)
top = ly.top_cell
puts "Renaming top cell #{top.name} -> #{$newname}"
top.name = $newname
ly.write($output)
