import 'package:flutter/material.dart';

import 'admin_contact_screen.dart';
import 'data/help_center_content.dart';
import 'help_article_detail_screen.dart';
import 'services/admin_support_config.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconFor(String iconName) {
    return switch (iconName) {
      'payment' => Icons.payments_outlined,
      'inventory' => Icons.inventory_2_outlined,
      'store' => Icons.storefront_outlined,
      'account' => Icons.person_outline_rounded,
      'bug' => Icons.bug_report_outlined,
      _ => Icons.receipt_long_outlined,
    };
  }

  void _openArticle(HelpArticle article) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpArticleDetailScreen(article: article),
      ),
    );
  }

  void _openCategory(HelpCategory category) {
    final items = HelpCenterContent.forCategory(category.key);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              Text(
                category.labelTh,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final article in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(article.titleTh),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).pop();
                    _openArticle(article);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = HelpCenterContent.search(_query);
    final popular = HelpCenterContent.popularArticles();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ศูนย์ช่วยเหลือ Van Market'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'ค้นหาคำถาม เช่น ออเดอร์ สินค้า รายได้',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (_query.trim().isEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'คำถามยอดนิยม',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final article in popular)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(article.titleTh),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openArticle(article),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'หมวดหมู่',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final category in HelpCenterContent.categories)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_iconFor(category.iconName)),
                  title: Text(category.labelTh),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _openCategory(category),
                ),
              ),
          ] else ...<Widget>[
            const SizedBox(height: 16),
            for (final article in results)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(article.titleTh),
                  subtitle: Text(
                    article.bodyTh,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _openArticle(article),
                ),
              ),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'ไม่พบบทความ',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Text(
            'ยังต้องการความช่วยเหลือ?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminContactScreen(
                    config: kVan1AdminSupportConfig,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('ติดต่อแอดมิน'),
          ),
        ],
      ),
    );
  }
}
