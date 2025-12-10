import 'package:flutter/material.dart';

class PregnancyBlogScreen extends StatefulWidget {
  const PregnancyBlogScreen({super.key});

  @override
  State<PregnancyBlogScreen> createState() => _PregnancyBlogScreenState();
}

class _PregnancyBlogScreenState extends State<PregnancyBlogScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pregnancy Blog'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Patient teal gradient
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF32CCBC), Color(0xFF90F7EC)], // Patient teal gradient
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white, // White text for selected tabs
              unselectedLabelColor: Colors.white.withOpacity(0.7), // Semi-transparent white for unselected
              indicatorColor: Colors.white, // White indicator
              tabs: const [
                Tab(text: 'First Trimester'),
                Tab(text: 'Second Trimester'),
                Tab(text: 'Third Trimester'),
                Tab(text: 'General Tips'),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFirstTrimesterContent(),
                _buildSecondTrimesterContent(),
                _buildThirdTrimesterContent(),
                _buildGeneralTipsContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTrimesterContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlogCard(
            'Understanding Your First Trimester',
            'The first trimester is a crucial time for your baby\'s development. Learn what to expect and how to take care of yourself during these important weeks.',
            'assets/images/Female/pat/love.png',
            [
              'Weeks 1-4: Early development and implantation',
              'Weeks 5-8: Major organs begin forming',
              'Weeks 9-12: Baby\'s basic structure is complete',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Managing Morning Sickness',
            'Morning sickness affects up to 80% of pregnant women. Discover effective strategies to manage nausea and vomiting during your first trimester.',
            'assets/images/Female/pat/love.png',
            [
              'Eat small, frequent meals throughout the day',
              'Stay hydrated with water, ginger tea, or lemon water',
              'Avoid strong smells and foods that trigger nausea',
              'Get plenty of rest and avoid fatigue',
              'Consider acupressure wristbands',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Essential Nutrients for Early Pregnancy',
            'Your baby needs specific nutrients for healthy development. Learn about the most important vitamins and minerals for the first trimester.',
            'assets/images/Female/pat/love.png',
            [
              'Folic acid: Prevents neural tube defects',
              'Iron: Prevents anemia and supports baby\'s growth',
              'Calcium: Builds strong bones and teeth',
              'Protein: Essential for baby\'s cell development',
              'Omega-3 fatty acids: Supports brain development',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondTrimesterContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlogCard(
            'The "Honeymoon" Phase of Pregnancy',
            'The second trimester is often called the most comfortable period of pregnancy. Learn how to make the most of this time.',
            'assets/images/Female/pat/love.png',
            [
              'Energy levels typically improve',
              'Morning sickness usually subsides',
              'Baby\'s movements become noticeable',
              'Your belly starts showing',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Feeling Your Baby Move',
            'One of the most exciting moments is feeling your baby\'s first movements. Learn what to expect and when to be concerned.',
            'assets/images/Female/pat/love.png',
            [
              'First movements usually felt between 16-22 weeks',
              'Initially feels like flutters or bubbles',
              'Movements become stronger and more regular',
              'Count kicks starting around 28 weeks',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Exercise During Pregnancy',
            'Staying active during pregnancy benefits both you and your baby. Learn safe exercises for the second trimester.',
            'assets/images/Female/pat/love.png',
            [
              'Walking: Safe and effective cardiovascular exercise',
              'Prenatal yoga: Improves flexibility and reduces stress',
              'Swimming: Low-impact full-body workout',
              'Pilates: Strengthens core and pelvic floor',
              'Always consult your healthcare provider first',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThirdTrimesterContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlogCard(
            'Preparing for Labor and Delivery',
            'The third trimester is all about preparation. Learn what you need to know about labor, delivery, and postpartum care.',
            'assets/images/Female/pat/love.png',
            [
              'Create a birth plan',
              'Pack your hospital bag',
              'Install the car seat',
              'Take childbirth classes',
              'Choose a pediatrician',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Managing Third Trimester Discomfort',
            'The final weeks can be challenging. Learn how to manage common third trimester symptoms.',
            'assets/images/Female/pat/love.png',
            [
              'Back pain: Use proper posture and support',
              'Heartburn: Eat smaller meals and avoid spicy foods',
              'Swelling: Elevate feet and stay hydrated',
              'Sleep difficulties: Use pregnancy pillows',
              'Braxton Hicks contractions: Normal practice contractions',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Signs of Labor',
            'Knowing the signs of labor helps you prepare for the big day. Learn what to watch for and when to call your doctor.',
            'assets/images/Female/pat/love.png',
            [
              'Regular contractions that get stronger and closer',
              'Water breaking (clear fluid)',
              'Bloody show (mucus with blood)',
              'Lower back pain and pressure',
              'Nesting instinct and energy burst',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTipsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBlogCard(
            'Nutrition During Pregnancy',
            'Eating well during pregnancy is crucial for your baby\'s development. Learn about a healthy pregnancy diet.',
            'assets/images/Female/pat/love.png',
            [
              'Eat a variety of fruits and vegetables',
              'Choose whole grains over refined grains',
              'Include lean protein sources',
              'Limit processed foods and added sugars',
              'Stay hydrated with water',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Mental Health During Pregnancy',
            'Pregnancy can bring emotional challenges. Learn how to maintain good mental health throughout your pregnancy.',
            'assets/images/Female/pat/love.png',
            [
              'Practice stress-reduction techniques',
              'Stay connected with loved ones',
              'Join pregnancy support groups',
              'Consider therapy if needed',
              'Practice self-care regularly',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Pregnancy Safety Guidelines',
            'Keeping yourself and your baby safe during pregnancy is essential. Learn important safety guidelines.',
            'assets/images/Female/pat/love.png',
            [
              'Avoid alcohol, smoking, and drugs',
              'Limit caffeine intake',
              'Avoid raw fish and undercooked meat',
              'Stay away from harmful chemicals',
              'Get regular prenatal care',
            ],
          ),
          const SizedBox(height: 16),
          _buildBlogCard(
            'Preparing for Parenthood',
            'Becoming a parent is a major life change. Learn how to prepare emotionally and practically for your new role.',
            'assets/images/Female/pat/love.png',
            [
              'Read parenting books and articles',
              'Talk to experienced parents',
              'Prepare your home for baby',
              'Plan for postpartum support',
              'Discuss parenting philosophies with your partner',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlogCard(String title, String description, String imagePath, List<String> points) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.purple[100],
                  ),
                  child: Image.asset(
                    imagePath,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...points.map((point) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.purple, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
} 