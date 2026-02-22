import re

file_path = "lib/okovita_web/live/admin/media_live/index.ex"

with open(file_path, "r") as f:
    content = f.read()

target = """            <div class="flex items-center gap-2 bg-indigo-50 px-3 py-1.5 rounded-full border border-indigo-100 animate-fade-in shadow-sm">
              <span class="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-600 text-[10px] font-bold text-white">
                <%= MapSet.size(@selected_media) %>
              </span>
              <span class="text-xs font-medium text-indigo-900 hidden sm:inline-block mr-1">zaznaczonych</span>

              <button type="button" phx-click="clear-selection" class="px-2 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100 rounded transition-colors">
                Anuluj
              </button>

              <div class="w-px h-4 bg-indigo-200 mx-1"></div>

              <button type="button" phx-click="request-delete-batch" class="px-2 py-1 flex items-center gap-1 text-xs font-medium text-red-600 hover:bg-red-50 hover:text-red-700 rounded transition-colors" title="Usuń zaznaczone">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                <span class="hidden sm:inline-block">Usuń</span>
              </button>
            </div>"""

replacement = """            <div class="flex items-center gap-3 bg-white px-3 py-1.5 rounded-md border border-gray-200 animate-fade-in shadow-sm">
              <span class="text-xs font-medium text-gray-700">
                Wybrano: <span class="font-semibold text-gray-900"><%= MapSet.size(@selected_media) %></span>
              </span>

              <div class="w-px h-4 bg-gray-200 mx-1"></div>

              <button type="button" phx-click="clear-selection" class="px-2 py-1 text-xs font-medium text-gray-700 hover:bg-gray-100 rounded-md transition-colors">
                Anuluj
              </button>

              <button type="button" phx-click="request-delete-batch" class="px-2 py-1 flex items-center gap-1.5 text-xs font-medium text-red-600 hover:bg-red-50 hover:text-red-700 rounded-md transition-colors" title="Usuń zaznaczone">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                <span class="hidden sm:inline-block">Usuń</span>
              </button>
            </div>"""

if target in content:
    content = content.replace(target, replacement)
    with open(file_path, "w") as f:
        f.write(content)
    print("Success: direct match replaced")
else:
    # Let's try to remove whitespace and match to be safe
    import re
    # normalize whitespace to space
    target_norm = re.sub(r'\s+', ' ', target)
    content_norm = re.sub(r'\s+', ' ', content)
    if target_norm in content_norm:
        print("Success: matched but with diff whitespace... I'll need a better regex.")
    else:
        print("Error: Could not find target")
