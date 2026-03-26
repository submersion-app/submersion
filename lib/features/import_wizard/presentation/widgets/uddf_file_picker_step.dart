import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/features/dive_import/data/services/uddf_parser_service.dart';
import 'package:submersion/features/import_wizard/data/adapters/uddf_adapter.dart';

class UddfFilePickerStep extends ConsumerStatefulWidget {
  const UddfFilePickerStep({
    super.key,
    required this.parser,
    required this.onDataParsed,
  });

  final UddfParserService parser;
  final void Function(UddfImportResult data) onDataParsed;

  @override
  ConsumerState<UddfFilePickerStep> createState() => _UddfFilePickerStepState();
}

class _UddfFilePickerStepState extends ConsumerState<UddfFilePickerStep> {
  bool _isParsing = false;
  String? _error;
  UddfImportResult? _parsedData;

  Future<void> _pickAndParseFile() async {
    setState(() {
      _isParsing = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isParsing = false);
        return;
      }

      final pickedFile = result.files.first;
      final ext = pickedFile.extension?.toLowerCase();
      if (ext != 'uddf' && ext != 'xml') {
        setState(() {
          _isParsing = false;
          _error = 'Please select a UDDF or XML file';
        });
        return;
      }

      final filePath = pickedFile.path;
      if (filePath == null) {
        setState(() {
          _isParsing = false;
          _error = 'Could not access file';
        });
        return;
      }

      final file = File(filePath);
      final content = await file.readAsString();
      final parsed = await widget.parser.parseContent(content);

      // Attach the source filename so it flows through to DiveDataSource
      // records created during import.
      final fileName = filePath.split('/').last;
      final data = parsed.copyWithSourceFileName(fileName);

      widget.onDataParsed(data);

      if (mounted) {
        setState(() {
          _isParsing = false;
          _parsedData = data;
        });
        ref.read(uddfAdapterCanAdvanceProvider.notifier).state = !data.isEmpty;
      }
    } on UddfParseException catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
          _error = 'Failed to parse file: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            icon: _isParsing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_open),
            label: Text(_isParsing ? 'Parsing...' : 'Select File'),
            onPressed: _isParsing ? null : _pickAndParseFile,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        if (_parsedData != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _parsedData!.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: _parsedData == null
              ? _buildEmptyState(context, theme)
              : _buildSummary(theme),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.file_open,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('No file loaded', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Select a .uddf or .xml file to import dive data.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(ThemeData theme) {
    final data = _parsedData!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.check_circle,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text('File parsed successfully', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${data.totalItems} items found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
