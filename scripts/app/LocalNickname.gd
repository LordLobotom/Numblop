class_name LocalNickname
extends RefCounted

const MAX_LENGTH := 16


static func sanitize(raw: String) -> String:
    var cleaned := ""
    for character in raw.strip_edges():
        if character.unicode_at(0) >= 32:
            cleaned += character
    return cleaned.strip_edges().left(MAX_LENGTH)
