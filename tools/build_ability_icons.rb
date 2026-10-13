root = File.expand_path('../assets/spells', __dir__)
icons = {
  'strike' => ['e1d0ab', '<path d="m12 36 23-27 4-2-1 7-22 25z"/><path d="m9 27 13 11m-15 3 7-8" fill="none" stroke="#f3e9d7" stroke-width="4"/>'],
  'cleave' => ['ffba82', '<path d="M8 32Q20 3 41 9L26 30Z"/><path d="m14 29 11 11m-17 2 9-9" fill="none" stroke="#ffe2bd" stroke-width="4"/>'],
  'guard' => ['a1cbd7', '<path d="m24 4 16 7v13q-1 12-16 20Q9 36 8 24V11Z"/><path d="M24 10v27M13 17h22" fill="none" stroke="#e4f3f7" stroke-width="3"/>'],
  'dash' => ['e6c99a', '<path d="m9 10 15 14L9 38V27H3v-6h6zM27 10l16 14-16 14V27h-5v-6h5Z"/>'],
  'storm' => ['b2cfff', '<path d="M28 3 9 27h13l-3 18 20-27H26Z"/>'],
  'meteor' => ['ff855c', '<circle cx="16" cy="31" r="11"/><path d="m13 22 23-18-10 19L43 10 28 32Z"/>'],
  'mend' => ['9ae3ba', '<path d="M19 5h10v14h14v10H29v14H19V29H5V19h14Z"/>'],
  'whirlwind' => ['ead5ad', '<path d="M38 14A17 17 0 1 0 37 36" fill="none" stroke="#ead5ad" stroke-width="6"/><path d="m28 4 15 5-2 16Z"/>'],
  'second_wind' => ['99d3ae', '<path d="M8 37Q4 9 40 5q5 29-27 33Z"/><path d="m11 35 23-22" fill="none" stroke="#e0f5e5" stroke-width="3"/>'],
  'execute' => ['f3a1a1', '<path d="M6 5h7l29 30-7 7L5 13ZM35 5h7v8L13 42l-7-7Z"/>'],
  'runeblade' => ['b49ded', '<path d="m12 36 23-27 4-2-1 7-22 25z"/><path d="m9 27 13 11m2-28 5 5-5 5-5-5Z" fill="none" stroke="#e4d4ff" stroke-width="3"/>']
}
icons.each do |name, (color, geometry)|
  File.write(File.join(root, "#{name}.svg"), %(<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48"><g fill="##{color}" stroke-linecap="round" stroke-linejoin="round">#{geometry}</g></svg>\n))
end
