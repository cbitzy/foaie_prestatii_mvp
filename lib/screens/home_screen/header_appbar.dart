// /lib/screens/screens/home_screen/header_appbar.dart

import 'package:flutter/material.dart';

class HomeAppBarTitle extends StatelessWidget {
  final String name;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenRaport;

  const HomeAppBarTitle({
    super.key,
    required this.name,
    required this.onOpenSettings,
    required this.onOpenRaport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titlu + setări (dreapta)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Program Prestatii Mecanic',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Setări aplicație',
                icon: const Icon(Icons.settings),
                onPressed: onOpenSettings,
              ),
            ],
          ),
          // Nume (stânga) și Raport lunar (dreapta)
          if (name.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Raport lunar',
                    icon: const Icon(Icons.train),
                    onPressed: onOpenRaport,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
