# Seed mentors matching StudyPal Figma design
mentors_data = [
  {
    name: "Dr. Lena Ortiz",
    role: "Mathematics & Statistics",
    image: "https://images.unsplash.com/photo-1643297654473-049b273de9e6?auto=format&fit=crop&w=500&q=85",
    rating: 4.9,
    sessions_count: "240+ sessions",
    tags: "Calculus, Statistics",
    color: "#f4dcff"
  },
  {
    name: "Noah Williams",
    role: "Computer Science",
    image: "https://images.unsplash.com/photo-1787647560526-655b78e31453?auto=format&fit=crop&w=500&q=85",
    rating: 4.8,
    sessions_count: "180+ sessions",
    tags: "Python, Algorithms",
    color: "#d7f2ed"
  },
  {
    name: "James Chen",
    role: "Physics & Engineering",
    image: "https://images.unsplash.com/photo-1544168190-79c17527004f?auto=format&fit=crop&w=500&q=85",
    rating: 5.0,
    sessions_count: "315+ sessions",
    tags: "Physics, Mechanics",
    color: "#ffe9cc"
  }
]

mentors = mentors_data.map do |attrs|
  Mentor.find_or_create_by!(name: attrs[:name]) do |m|
    m.role = attrs[:role]
    m.image = attrs[:image]
    m.rating = attrs[:rating]
    m.sessions_count = attrs[:sessions_count]
    m.tags = attrs[:tags]
    m.color = attrs[:color]
  end
end

lena = mentors.first
MentoringSession.find_or_create_by!(student_name: "Maya", mentor: lena, topic: "Integration techniques") do |s|
  s.subject = "CALCULUS"
  s.session_date = Date.new(2026, 3, 14)
  s.start_time = "10:30 AM"
  s.end_time = "11:15 AM"
  s.status = "confirmed"
  s.help_type = "Assignment review"
end

puts "Seeded #{Mentor.count} mentors and #{MentoringSession.count} mentoring sessions."
