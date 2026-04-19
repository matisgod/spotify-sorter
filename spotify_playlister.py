import json
import requests
import string
import matplotlib.pyplot as plt

API_KEY = "7e9eabc4a20205254540ba42385f9e99"
SHARED_SECRET = "23dd090004f3dc5d8a743ccb823a3afb"
JSON_FILE = "my_spotify_data/Spotify Account Data/Playlist1.json" # Change this to match the (relative) path to your spotify json data


def open_file(file=JSON_FILE):
    """Opens json file and extracts the data as embedded dictionaries/lists."""
    with open(file, "r", encoding="utf-8") as json_data:
        data = json.load(json_data)
    return data


def playlist_lister(playlist_data):
    # print(playlist_data)
    """Takes the data and extracts the playlist names, printing them one by one."""
    for playlist in playlist_data["playlists"]:

        print(playlist["name"])
    return None


def song_playlist_lister(playlist):
    """Takes a playlist and lists the songs in the playlist."""
    for song in playlist["items"]:
        print(song["track"]["trackName"])
    return None


def playlist_isolater(data):
    """Probably don't need?"""
    data_filtered = [
        playlist for playlist in data if playlist["name"].startswith("Playlist no.")]
    return data_filtered


def unique_tracks_lister(data_list):
    """Creates a list of all unique songs in all playlists."""
    unique_tracks = []
    seen_songs = []
    for playlist in data_list["playlists"]:
        for song in playlist["items"]:
            if song not in seen_songs:
                # print(song["track"])
                unique_tracks.append(song["track"])
            else:
                seen_songs.append(song)
    return unique_tracks


def get_track_tags(track_name, artist_name):
    """Takes the tags created for each song by the last.fm's API to generate genre names for each song."""
    url = "http://ws.audioscrobbler.com/2.0/"

    params = {
        "method": "track.getTopTags",
        "track": track_name,
        "artist": artist_name,
        "api_key": API_KEY,
        "format": "json"
    }

    try:
        r = requests.get(url, params=params)
        data = r.json()
        tags = data["toptags"]["tag"]
        return [tag["name"] for tag in tags[:5]]
    except (requests.exceptions.JSONDecodeError, KeyError, TypeError):
        print(track_name)
        return []


def get_artist_tags(artist_name):
    """Takes the tags created for each artist by the last.fm's API to generate genre names for each song."""
    url = "http://ws.audioscrobbler.com/2.0/"

    params = {
        "method": "artist.getTopTags",
        "artist": artist_name,
        "api_key": API_KEY,
        "format": "json"
    }

    try:
        r = requests.get(url, params=params)
        data = r.json()
        tags = data["toptags"]["tag"]
    except (requests.exceptions.JSONDecodeError, KeyError, TypeError):
        print(artist_name)
        return []
    return [tag["name"] for tag in tags[:5]]


not_recognised = ["Ruba-Dub", "A fast drive through the universe"]


def edit_not_recognised(not_recognised: list):
    running = True
    add_remove = None
    while running:
        string_add_remove = input(
            "Do you want to add (a) or remove (r) a track from the \"Not recognised\" list? ")
        if string_add_remove.lower() == "a":
            add_remove = True
            running = False
        elif string_add_remove.lower() == "r":
            add_remove = False
            running = False
        else:
            print("Please enter \"a\" to add a song, or \"r\" to remove a song.")
    track_name = input("What is the name of the song?")
    if add_remove:
        not_recognised.append(track_name)
    else:
        not_recognised.remove(track_name)
    return not_recognised


def set_genres_tags(tracks, not_recognised):
    for track in tracks:
        track_name = track["trackName"]
        if track_name not in not_recognised:
            track_artist = track["artistName"]
            genres = get_track_tags(track_name, track_artist)
            if genres == []:
                genres = get_artist_tags(track_artist)
            track["genres"] = genres
        else:
            track["genres"] = []
    return tracks


def check_number(number_string):
    digits = string.digits
    return True if all(char in digits for char in number_string) else False


def get_genres():
    input_running = True
    num_genres = 0
    while input_running:
        str_num_genres = input("How many genres do you want to add (max 5)?")
        if check_number(str_num_genres):
            num_genres_try = int(str_num_genres)
            if num_genres_try > 0 and num_genres_try <= 5:
                num_genres = num_genres_try
                input_running = False
            else:
                print("Please enter a number from 1 to 5.")
        else:
            print("Please enter a valid number")
    i = 0
    genres = []
    while i < num_genres:
        genre_temp = input("What is the name of the genre?")
        genres.append(genre_temp)
    return genres


def set_genres(tracks, name, genres):
    for track in tracks:
        if track["trackName"] == name:
            track["genres"] = genres
    return tracks


def list_no_genres(tracks):
    genreless = []
    for track in tracks:
        if track["genres"] == []:
            genreless.append(track)
    return genreless


def choice_picker():
    running = True
    while running:
        yes_no_string = input("Yes (y) or no (n)?")
        if yes_no_string.lower() == "y":
            return True
        elif yes_no_string.lower() == "n":
            return False
        else:
            print("Please enter \"y\" for yes or \"n\" for no.")

def extract_file_menu():
    print("Do you want to input the file path?")
    file_selector_bool = choice_picker()
    if file_selector_bool:
        file_opening = True
        while file_opening:
            file_path = input("Please enter the file path:")
            try:
                raw_data = open_file(file_path)
            except FileNotFoundError:
                print("The file was not found. Please try again.")
    else:
        raw_data = open_file()
    return raw_data

def sort_genres(tracks):
    genres_dict = {}
    for track in tracks:
        for genre in track["genres"]:
            if genre not in genres_dict:
                genres_dict[genre] = []
            genres_dict[genre].append(track)
    return genres_dict

def json_store_file(genre_dict):
    with open('genres_dictionary.json','w') as json_data:
        data = json.dump(genre_dict,json_data, indent=3)
    return data

def genre_adder_menu(spotify_data,unrecognised_songs,unique_tracks,tagged_tracks,genreless_tracks):
    main_menu_string = """
Press 1 to see your playlist names.
Press 2 to change the list of songs unrecognised by last.fm.
Press 3 to list the songs in your library that don't have a genre assigned to them.
Press 4 to add (a) genre(s) to a song.
Press 5 to sort by genres.
Press \'E\' to exit.
"""
    menu_running = True
    while menu_running:
        print(main_menu_string)
        menu_input = input("Please enter your choice here: ")
        if menu_input == "1":
            playlist_lister(spotify_data)
        elif menu_input == "2":
            unrecognised_songs = edit_not_recognised(unrecognised_songs)
        elif menu_input == "3":
            for song in genreless_tracks:
                print(song["track"]["trackName"])
        elif menu_input == "4":
            song_string = input("What is the name of the song you would like to add genres to?")
            artist_string = input("What is the name of the artist that wrote this song?")
            genres_to_add = get_genres()
            unique_tracks = set_genres(unique_tracks,song_string,artist_string,genres_to_add)
        elif menu_input == "5":
            sorted_dictionary = sort_genres(unique_tracks)
            menu_running = False
        elif menu_input.lower() == "e":
            menu_running = True
        else:
            print("Please enter a valid input.")
    return unrecognised_songs,unique_tracks,tagged_tracks,genreless_tracks, sorted_dictionary

def sorted_menu(sorted_dictionary,raw_spotify_data,unique_tracks,tagged_tracks,unrecognised_songs,genreless_tracks):
    sorted_string = """
    Your playlists have been sorted.
    What would you like to do with this information?
    Press 1 to save this information in a .txt file.
    Press 2 to show this as a png file (will not automatically save).
    Press 3 to return to the genre editing menu.
    Press 4 to exit (will not save).
    """
    sorted_menu_running = True
    while sorted_menu_running:
        print(sorted_string)
        sorted_menu_input = input("Please enter your input here: ")
        if sorted_menu_input == "1":
            json_store_file(sorted_dictionary)
        elif sorted_menu_input == "2":
            data = json_store_file(sorted_dictionary)
            fig,ax = plt.subplots(figsize = (6,4))
            ax.text(0.1,0.5,data,fontsize = 12)
            ax.axis('off')
            plt.savefig('genres.png',dpi = 600)
        elif sorted_menu_input == "3":
            _,unique_tracks,tagged_tracks,_, sorted_dictionary = genre_adder_menu(raw_spotify_data,unrecognised_songs,unique_tracks,tagged_tracks,genreless_tracks)
        elif sorted_menu_input == "4":
            sorted_menu_running = False
    return None

def main():
    opening_string = """
Welcome to the Spotify genre sorter! 
Please have your spotify data downloaded onto your computer for this to work.
"""
    print(opening_string)
    raw_spotify_data = extract_file_menu()
    unrecognised_songs = []
    unique_tracks = unique_tracks_lister(raw_spotify_data)
    tagged_tracks = set_genres_tags(unique_tracks,unrecognised_songs)
    genreless_tracks = list_no_genres(tagged_tracks)

    unrecognised_songs,unique_tracks,tagged_tracks,genreless_tracks, sorted_dictionary = genre_adder_menu(raw_spotify_data,unrecognised_songs,unique_tracks,tagged_tracks,genreless_tracks)
    data = json_store_file(sorted_dictionary)
    _,raw_spotify_data,unique_tracks,tagged_tracks = sorted_menu(sorted_dictionary,raw_spotify_data,unique_tracks,tagged_tracks,unrecognised_songs,genreless_tracks)
    
    return None

main()