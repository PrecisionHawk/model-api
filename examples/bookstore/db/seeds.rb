# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

puts "Seeding genres ..."
Genre.create([
    { name: 'Science Fiction' }, { name: 'Satire' }, { name: 'Drama' }, { name: 'Classics' },
    { name: 'Action and Adventure' }, { name: 'Romance' }, { name: 'Mystery' }, { name: 'Horror' },
    { name: 'Self-Help' }, { name: 'Health' }, { name: 'Guide' }, { name: 'Travel' },
    { name: "Children's" }, { name: 'Religion, Spirituality & New Age' }, { name: 'Science' },
    { name: 'History' }, { name: 'Math' }, { name: 'Anthology' }, { name: 'Poetry' },
    { name: 'Encyclopedias' }, { name: 'Dictionaries' }, { name: 'Comics' }, { name: 'Art' },
    { name: 'Cookbooks' }, { name: 'Diaries' }, { name: 'Journals' }, { name: 'Prayer Books' },
    { name: 'Series' }, { name: 'Trilogy' }, { name: 'Biographies' }, { name: 'Autobiographies' },
    { name: 'Fantasy' }
])

puts "Seeding authors ..."
Author.create([
    { display_name: 'Isaac Asimov', first_name: 'Isaac', last_name: 'Asimov',
        genres: [Genre.find_by_name('Science Fiction')],
        primary_genre: Genre.find_by_name('Science Fiction') },
    { display_name: 'Stephen Colbert', first_name: 'Stephen', last_name: 'Colbert',
        genres: [Genre.find_by_name('Satire')],
        primary_genre: Genre.find_by_name('Satire') },
    { display_name: 'William Shakespeare', first_name: 'William', last_name: 'Shakespeare',
        genres: [Genre.find_by_name('Drama'), Genre.find_by_name('Classics')],
        primary_genre: Genre.find_by_name('Drama') },
    { display_name: 'Clive Cussler', first_name: 'Clive', last_name: 'Cussler',
        genres: [Genre.find_by_name('Action and Adventure'), Genre.find_by_name('Drama')],
        primary_genre: Genre.find_by_name('Action and Adventure') },
    { display_name: 'Jane Austen', first_name: 'Jane', last_name: 'Austen',
        genres: [Genre.find_by_name('Romance'), Genre.find_by_name('Classics')],
        primary_genre: Genre.find_by_name('Romance') },
    { display_name: 'Agatha Christie', first_name: 'Agatha', last_name: 'Christie',
        genres: [Genre.find_by_name('Mystery')],
        primary_genre: Genre.find_by_name('Mystery') },
    { display_name: 'Stephen King', first_name: 'Stephen', last_name: 'King',
        genres: [Genre.find_by_name('Horror')],
        primary_genre: Genre.find_by_name('Horror') },
    { display_name: 'Dr. Seuss', first_name: 'Theodor Seuss', last_name: 'Geisel',
        genres: [Genre.find_by_name("Children's")],
        primary_genre: Genre.find_by_name("Children's") },
    { display_name: 'Robert Frost', first_name: 'Robert', last_name: 'Frost',
        genres: [Genre.find_by_name('Poetry')],
        primary_genre: Genre.find_by_name('Poetry') },
    { display_name: 'Dale Carnegie', first_name: 'Dale', last_name: 'Carnegie',
        genres: [Genre.find_by_name('Science Fiction')],
        primary_genre: Genre.find_by_name('Science Fiction') },
    { display_name: 'J.R.R. Tolkien', first_name: 'John Ronald Reuel', last_name: 'Tolkien',
        genres: [Genre.find_by_name('Fantasy')],
        primary_genre: Genre.find_by_name('Fantasy') }
])

puts "Seeding books ..."
Book.create([
    {
        name: 'Foundation', isbn: '9780553293357', price: 7.19,
        description: "Mankind's last best hope is faced with an agonizing choice: submit to the " \
            "barbarians and be overrun--or fight them and be destroyed.",
        authors: [Author.find_by_display_name('Isaac Asimov')],
        genres: [Genre.find_by_name('Science Fiction')],
        primary_genre: Genre.find_by_name('Science Fiction')
    },
    {
        name: 'I, Robot', isbn: '9780553382563', price: 11.02,
        description: "A millennium into the future two advances have altered the course of human " \
            "history: the colonization of the Galaxy and the creation of the positronic brain.",
        authors: [Author.find_by_display_name('Isaac Asimov')],
        genres: [Genre.find_by_name('Science Fiction')],
        primary_genre: Genre.find_by_name('Science Fiction')
    },
    {
        name: 'The Robots of Dawn', isbn: '9780553299496', price: 7.43,
        description: "Isaac Asimov's Robot novels chronicle the unlikely partnership between a " \
            "New York City detective and a humanoid robot who must learn to work together.",
        authors: [Author.find_by_display_name('Isaac Asimov')],
        genres: [Genre.find_by_name('Science Fiction')],
        primary_genre: Genre.find_by_name('Science Fiction')
    },
    {
        name: 'I Am America (And So Can You!)', isbn: '9780446582186', price: 10.81,
        description: " AM AMERICA (AND SO CAN YOU!) is Stephen Colbert's attempt to wedge his " \
            "brain between hardback covers.",
        authors: [Author.find_by_display_name('Stephen Colbert')],
        genres: [Genre.find_by_name('Satire')],
        primary_genre: Genre.find_by_name('Satire')
    },
    {
        name: "Shakespeare's Sonnets", isbn: '9781533690791', price: 5.39,
        description: "Shakespeare's Sonnets is the title of a collection of 154 sonnets " \
            "accredited to William Shakespeare which cover themes such as the passage of time, " \
            "love, beauty and mortality.",
        authors: [Author.find_by_display_name('William Shakespeare')],
        genres: [Genre.find_by_name('Drama')],
        primary_genre: Genre.find_by_name('Drama')
    },
    {
        name: 'Pirate', isbn: '9780399183973', price: 19.88,
        description: "When husband and wife treasure hunters Sam and Remi Fargo try something " \
            "new, a relaxing vacation, a detour to visit a rare bookstore leads to the discovery " \
            "of a dead body.",
        authors: [Author.find_by_display_name('Clive Cussler')],
        genres: [Genre.find_by_name('Action and Adventure')],
        primary_genre: Genre.find_by_name('Action and Adventure')
    },
    {
        name: 'Odessa Sea', isbn: '9780399575518', price: 21.25,
        description: "When husband and wife treasure hunters Sam and Remi Fargo try something " \
            "new, a relaxing vacation, a detour to visit a rare bookstore leads to the discovery " \
            "of a dead body.",
        authors: [Author.find_by_display_name('Clive Cussler')],
        genres: [Genre.find_by_name('Action and Adventure')],
        primary_genre: Genre.find_by_name('Action and Adventure')
    },
    {
        name: 'Sense and Sensibility', isbn: '9780141439662', price: 9.92,
        description: "Marianne Dashwood wears her heart on her sleeve, and when she falls in " \
            "love with the dashing but unsuitable John Willoughby she ignores her sister " \
            "Elinor's warning that her impulsive behaviour leaves her open to gossip and innuendo.",
        authors: [Author.find_by_display_name('Jane Austen')],
        genres: [Genre.find_by_name('Romance')],
        primary_genre: Genre.find_by_name('Romance')
    },
    {
        name: 'Murder on the Orient Express', isbn: '9780062073501', price: 13.85,
        description: "Murder on the Orient Express, the most famous Hercule Poirot mystery, " \
            "showcases the brilliant detective hunting for a killer aboard one of the world’s " \
            "most luxurious passenger trains.",
        authors: [Author.find_by_display_name('Agatha Christie')],
        genres: [Genre.find_by_name('Mystery')],
        primary_genre: Genre.find_by_name('Mystery')
    },
    {
        name: 'The Shining', isbn: '9780307743657', price: 5.39,
        description: "Jack Torrance’s new job at the Overlook Hotel is the perfect chance for a " \
            "fresh start.",
        authors: [Author.find_by_display_name('Stephen King')],
        genres: [Genre.find_by_name('Horror')],
        primary_genre: Genre.find_by_name('Horror')
    },
    {
        name: 'One Fish Two Fish Red Fish Blue Fish', isbn: '9780394800134', price: 6.02,
        description: "\"From there to here, from here to there, funny things are everywhere\" " \
            "... So begins this classic Beginner Book by Dr. Seuss.",
        authors: [Author.find_by_display_name('Dr. Seuss')],
        genres: [Genre.find_by_name("Children's")],
        primary_genre: Genre.find_by_name("Children's")
    },
    {
        name: 'Green Eggs and Ham', isbn: '9780394800165', price: 7.99,
        description: "\"Do you like green eggs and ham?\" asks Sam-I-am in this Beginner Book by " \
            "Dr. Seuss.",
        authors: [Author.find_by_display_name('Dr. Seuss')],
        genres: [Genre.find_by_name("Children's")],
        primary_genre: Genre.find_by_name("Children's")
    },
    {
        name: 'The Road Not Taken and Other Poems', isbn: '9780486275505', price: 5.84,
        description: "Two roads diverged in a wood, and I I took the one less traveled by, And " \
            "that has made all the difference.",
        authors: [Author.find_by_display_name('Robert Frost')],
        genres: [Genre.find_by_name('Poetry')],
        primary_genre: Genre.find_by_name('Poetry')
    },
    {
        name: 'How to Win Friends & Influence People', isbn: '9781508569756', price: 5.95,
        description: "For more than sixty years the rock-solid, time-tested advice in this book " \
            "has carried thousands of now famous people up the ladder of success in their " \
            "business and personal lives.",
        authors: [Author.find_by_display_name('Dale Carnegie')],
        genres: [Genre.find_by_name('Self-Help')],
        primary_genre: Genre.find_by_name('Self-Help')
    },
    {
        name: 'The Lord of the Rings', isbn: '9780618640157', price: 14.70,
        description: "One Ring to rule them all, One Ring to find them, One Ring to bring them " \
            "all and in the darkness bind them.",
        authors: [Author.find_by_display_name('J.R.R. Tolkien')],
        genres: [Genre.find_by_name('Fantasy')],
        primary_genre: Genre.find_by_name('Fantasy')
    },
    {
        name: 'The Hobbit', isbn: '9780547928227', price: 10.61,
        description: "Bilbo Baggins is a hobbit who enjoys a comfortable, unambitious life, " \
            "rarely traveling any farther than his pantry or cellar.",
        authors: [Author.find_by_display_name('J.R.R. Tolkien')],
        genres: [Genre.find_by_name('Fantasy')],
        primary_genre: Genre.find_by_name('Fantasy')
    },
    {
        name: 'The Two Towers', isbn: '9780547928203', price: 10.26,
        description: "Frodo and his Companions of the Ring have been beset by danger during " \
            "their quest to prevent the Ruling Ring from falling into the hands of the Dark Lord " \
            "by destroying it in the Cracks of Doom.",
        authors: [Author.find_by_display_name('J.R.R. Tolkien')],
        genres: [Genre.find_by_name('Fantasy')],
        primary_genre: Genre.find_by_name('Fantasy')
    }
])

puts "Seeding complete!"
