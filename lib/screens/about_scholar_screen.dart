import 'package:flutter/material.dart';
import '../theme/neumorphic.dart';

/// Biography of Sheikh Muhammad Auwal Adam Albaniy Zaria (1960-2014),
/// summarised from Wikipedia:
/// https://en.wikipedia.org/wiki/Muhammad_Auwal_Albani_Zaria
class AboutScholarScreen extends StatelessWidget {
  const AboutScholarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and title
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  NeumorphicCircleButton(
                    icon: Icons.arrow_back_ios_new,
                    size: 44,
                    iconSize: 18,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'About the Scholar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Portrait
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.background,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowDark.withOpacity(0.55),
                              offset: const Offset(6, 6),
                              blurRadius: 14,
                            ),
                            const BoxShadow(
                              color: AppColors.shadowLight,
                              offset: Offset(-6, -6),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/scholar_albaniy.png',
                            width: 128,
                            height: 128,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 128,
                                height: 128,
                                color: AppColors.background,
                                child: const Icon(
                                  Icons.person_outline,
                                  size: 56,
                                  color: AppColors.accent,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Center(
                      child: Text(
                        'Sheikh Muhammad Auwal Adam\nAlbaniy Zaria',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Center(
                      child: Text(
                        '27 September 1960 - 1 February 2014',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Center(
                      child: Text(
                        'Islamic scholar - Hadith & Fiqh',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    _section(
                      title: 'Introduction',
                      body:
                          'Muhammad Auwal Adam, popularly known as Albaniy '
                          'Zaria, was a Nigerian Islamic scholar who '
                          'specialised in Hadith and Fiqh. He also studied '
                          'Islamic law, mass communication, telecommunications '
                          'engineering and information and communications '
                          'technology. He was a leading figure in the Salafi '
                          'movement in Nigeria and was regarded by many of his '
                          'contemporaries as one of the most influential '
                          'Salafi scholars of his generation. He was among the '
                          'first scholars in Nigeria to popularise the term '
                          '"Salafiyah" among a generation of students and '
                          'teachers of Islamic knowledge.',
                    ),

                    _section(
                      title: 'Early Life and Education',
                      body:
                          'He was born on 27 September 1960 in Zaria, Kaduna '
                          'State. He received his primary education locally and '
                          'later attended Barewa College. He studied mass '
                          'communication at Bayero University, Kano, and '
                          'obtained a degree in information technology from the '
                          'Federal University of Technology, Yola (now Modibbo '
                          'Adama University). At the time of his death he was a '
                          'postgraduate student in the Department of Electrical '
                          'Engineering at Ahmadu Bello University, Zaria.\n\n'
                          'Alongside his secular studies he devoted many years '
                          'to the study of the Islamic sciences, particularly '
                          'Hadith. He adopted the nickname "Albani" in '
                          'reference to the Syrian-Albanian Hadith scholar '
                          'Muhammad Nasiruddin al-Albani. His students were '
                          'spread across northern Nigeria, especially in Kaduna, '
                          'Kano, Katsina, Plateau and Bauchi states, as well as '
                          'other parts of Nigeria and neighbouring West African '
                          'countries.',
                    ),

                    _section(
                      title: 'Career and Activities',
                      body:
                          'He established and led the Daarul Hadeethis-Salafiyyah '
                          'school and the Markazu-Salafiyya centre in Tudun '
                          'Wada, Zaria, and founded the Albaniy Science Academy '
                          'in the Gaskiya layout of Zaria. He delivered regular '
                          'weekly lectures and annual Tafsir sessions, focusing '
                          'on Hadith and the interpretation of the Qur\u2019an '
                          'according to the understanding of the early '
                          'generations of Muslims (the salaf).\n\nHe combined '
                          'his religious teaching with professional work in '
                          'information technology and telecommunications, and '
                          'was known for travelling to other states in northern '
                          'Nigeria and occasionally to neighbouring countries '
                          'to deliver lectures.',
                    ),

                    _section(
                      title: 'Notable Works',
                      body:
                          'His teaching and recorded lectures focused on the '
                          'study of authentic Hadith collections, the rejection '
                          'of religious innovations (bid\u2019ah), and the '
                          'promotion of a Salafi understanding of Islam. '
                          'Recordings of his lessons on Sahih al-Bukhari and '
                          'other classical texts - including the Qurdubi '
                          'lessons featured in this app - remain widely '
                          'circulated among his students and listeners.',
                    ),

                    _section(
                      title: 'Death',
                      body:
                          'On the evening of 1 February 2014, after delivering '
                          'his regular Tafsir lecture at Markazu-Salafiyya in '
                          'Tudun Wada, Zaria, he was attacked by gunmen near '
                          'Magume junction while driving home with his family. '
                          'He was shot and later pronounced dead at St. Luke '
                          'Hospital in Wusasa, Zaria, at the age of 53. One of '
                          'his wives and one of his sons also died in the '
                          'attack. The Boko Haram leader Abubakar Shekau later '
                          'claimed responsibility for the killing. May Allah '
                          'have mercy upon him.',
                    ),

                    const SizedBox(height: 8),

                    const Center(
                      child: Text(
                        'Source: Wikipedia - Muhammad Auwal Albani Zaria',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({required String title, required String body}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Neumorphic(
        borderRadius: 20,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
