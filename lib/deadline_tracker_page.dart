import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'models/deadline.dart';
import 'services/deadline_service.dart';

class DeadlineTrackerPage extends StatefulWidget {
  const DeadlineTrackerPage({Key? key}) : super(key: key);

  @override
  State<DeadlineTrackerPage> createState() => _DeadlineTrackerPageState();
}

class _DeadlineTrackerPageState extends State<DeadlineTrackerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeadlineService>().loadDeadlines();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deadlineService = Provider.of<DeadlineService>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final accentColor = Theme.of(context).colorScheme.tertiary;
    
    if (deadlineService.isLoading) {
      return Center(
        child: LoadingAnimationWidget.stretchedDots(
          color: isDarkMode ? accentColor : primaryColor,
          size: 50,
        ),
      );
    }
    

    final recommendedTasks = deadlineService.getRecommendedTasksForToday();
    
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
   
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deadline Tracker',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your assignments and project deadlines',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard(
                  context: context,
                  title: "Today",
                  value: deadlineService.todaysDeadlines.length.toString(),
                  color: Colors.blue,
                  icon: Icons.today,
                  isDarkMode: isDarkMode,
                ),
                _buildStatCard(
                  context: context,
                  title: "Coming Week",
                  value: deadlineService.upcomingDeadlines.length.toString(),
                  color: Colors.green,
                  icon: Icons.calendar_month,
                  isDarkMode: isDarkMode,
                ),
                _buildStatCard(
                  context: context,
                  title: "Overdue",
                  value: deadlineService.getOverdueDeadlines().length.toString(),
                  color: Colors.red,
                  icon: Icons.warning_amber,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            if (recommendedTasks.isNotEmpty)
              _buildRecommendationBanner(recommendedTasks.length),
              
     
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: isDarkMode 
                  ? Colors.white 
                  : Theme.of(context).colorScheme.primary.withOpacity(0.9),
                labelColor: isDarkMode 
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white,
                unselectedLabelColor: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDarkMode 
                    ? Colors.white
                    : Theme.of(context).colorScheme.primary.withOpacity(0.9),
                ),
                overlayColor: MaterialStateProperty.resolveWith<Color?>(
                  (Set<MaterialState> states) {
                    if (states.contains(MaterialState.hovered))
                      return isDarkMode 
                        ? Colors.white.withOpacity(0.1)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.7);
                    if (states.contains(MaterialState.pressed))
                      return isDarkMode 
                        ? Colors.white.withOpacity(0.2)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.8);
                    return null;
                  },
                ),
                tabs: const [
                  Tab(text: "All Deadlines"),
                  Tab(text: "Today"),
                  Tab(text: "Upcoming"),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
       
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
               
                  _buildDeadlinesList(
                    deadlines: deadlineService.deadlines,
                    emptyMessage: "No deadlines to show",
                    deadlineService: deadlineService,
                  ),
                  
                 
                  _buildDeadlinesList(
                    deadlines: deadlineService.todaysDeadlines,
                    emptyMessage: "No deadlines for today",
                    deadlineService: deadlineService,
                  ),
                  
               
                  _buildDeadlinesList(
                    deadlines: deadlineService.upcomingDeadlines,
                    emptyMessage: "No upcoming deadlines",
                    deadlineService: deadlineService,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: deadlineService.deadlines.isNotEmpty ? FloatingActionButton(
        onPressed: () => _showAddDeadlineDialog(context),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add),
        tooltip: "Add new deadline",
      ) : null,
    );
  }


  Widget _buildRecommendationBanner(int taskCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.amber.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              taskCount > 1 
                ? "You have $taskCount recommended tasks for today" 
                : "You have 1 recommended task for today",
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward,
              color: Colors.amber.shade800,
              size: 20,
            ),
            onPressed: () {

              _tabController.animateTo(1);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

 
  Widget _buildStatCard({
    required BuildContext context,
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isDarkMode ? color.withOpacity(0.8) : color,
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

 
  Widget _buildDeadlinesList({
    required List<Deadline> deadlines,
    required String emptyMessage,
    required DeadlineService deadlineService,
  }) {
    if (deadlines.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => deadlineService.loadDeadlines(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
     
            SizedBox(height: MediaQuery.of(context).size.height * 0.05),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
       
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
               
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddDeadlineDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Deadline'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    
  
    final Map<DeadlineStatus, List<Deadline>> groupedDeadlines = {};
    

    for (final deadline in deadlines) {
      if (!groupedDeadlines.containsKey(deadline.status)) {
        groupedDeadlines[deadline.status] = [];
      }
      groupedDeadlines[deadline.status]!.add(deadline);
    }
    

    final orderedStatuses = [
      DeadlineStatus.overdue,
      DeadlineStatus.pending,
      DeadlineStatus.inProgress,
      DeadlineStatus.completed,
    ];
    
  
    final statusesWithDeadlines = orderedStatuses
        .where((status) => groupedDeadlines.containsKey(status))
        .toList();
    
    return RefreshIndicator(
      onRefresh: () => deadlineService.loadDeadlines(),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: statusesWithDeadlines.length,
        itemBuilder: (context, index) {
          final status = statusesWithDeadlines[index];
          final deadlinesForStatus = groupedDeadlines[status] ?? [];
          
       
          deadlinesForStatus.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
         
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        status.icon, 
                        color: status.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: status.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${deadlinesForStatus.length}",
                      style: TextStyle(
                        color: status.color,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
     
              ...deadlinesForStatus.map((deadline) => 
                _buildDeadlineCard(
                  deadline: deadline, 
                  context: context,
                  deadlineService: deadlineService,
                )
              ),
              
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }


  Widget _buildDeadlineCard({
    required Deadline deadline,
    required BuildContext context,
    required DeadlineService deadlineService,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('MMM d, y • h:mm a');
    final priorityColor = deadline.priority.color;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDeadlineDetails(context, deadline, deadlineService),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deadline.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: deadline.status == DeadlineStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateFormatter.format(deadline.dueDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          deadline.priority.icon,
                          size: 14,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deadline.priority.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
       
              if (deadline.description != null && deadline.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  deadline.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
           
              Row(
                children: [
                  _buildDeadlineCountdown(deadline),
                  const Spacer(),
                  
                
                  if (deadline.tags.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "#${deadline.tags.first}${deadline.tags.length > 1 ? ' +${deadline.tags.length - 1}' : ''}",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 16),
              
      
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (deadline.status != DeadlineStatus.completed)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text("Complete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                await deadlineService.markAsCompleted(deadline.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Marked as completed")),
                                );
                              },
                            ),
                          ),
                        
                        if (deadline.status == DeadlineStatus.pending) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.run_circle_outlined, size: 18),
                              label: const Text("Start"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                await deadlineService.markAsInProgress(deadline.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Marked as in progress")),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _showEditDeadlineDialog(context, deadline),
                      icon: Icon(
                        Icons.edit,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      tooltip: "Edit",
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _showDeleteConfirmation(context, deadline.id),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      tooltip: "Delete",
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildDeadlineCountdown(Deadline deadline) {
    if (deadline.status == DeadlineStatus.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 14,
              color: Colors.green,
            ),
            SizedBox(width: 4),
            Text(
              "Completed",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }
    
    if (deadline.isOverdue) {
      final daysOverdue = -deadline.daysRemaining;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 14,
              color: Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              daysOverdue > 0 
                  ? "$daysOverdue ${daysOverdue == 1 ? 'day' : 'days'} overdue" 
                  : "Overdue",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }
    
    if (deadline.isToday) {
  
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.access_time,
              size: 14,
              color: Colors.amber,
            ),
            const SizedBox(width: 4),
            Text(
              "Due today (${deadline.hoursRemaining}h left)",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.amber,
              ),
            ),
          ],
        ),
      );
    }
    
    if (deadline.isTomorrow) {
  
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event,
              size: 14,
              color: Colors.blue,
            ),
            SizedBox(width: 4),
            Text(
              "Due tomorrow",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    }
    
   
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today,
            size: 14,
            color: Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            "Due in ${deadline.daysRemaining} ${deadline.daysRemaining == 1 ? 'day' : 'days'}",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }


  void _showDeadlineDetails(BuildContext context, Deadline deadline, DeadlineService deadlineService) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dateFormatter = DateFormat('EEEE, MMMM d, y • h:mm a');
    final priorityColor = deadline.priority.color;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
   
            Row(
              children: [
                Icon(deadline.status.icon, color: deadline.status.color),
                const SizedBox(width: 8),
                Text(
                  deadline.status.name,
                  style: TextStyle(
                    color: deadline.status.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deadline.priority.icon, size: 16, color: priorityColor),
                      const SizedBox(width: 6),
                      Text(
                        deadline.priority.name,
                        style: TextStyle(
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
         
            Text(
              deadline.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 12),
            
         
            Row(
              children: [
                const Icon(Icons.event, size: 18),
                const SizedBox(width: 8),
                Text(dateFormatter.format(deadline.dueDate)),
                const Spacer(),
                _buildDeadlineCountdown(deadline),
              ],
            ),
            
         
            if (deadline.description != null && deadline.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Description",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(deadline.description!),
            ],
            
         
            if (deadline.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Tags",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: deadline.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text("#$tag"),
                )).toList(),
              ),
            ],
            
            const SizedBox(height: 24),
            
           
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (deadline.status != DeadlineStatus.completed)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("Complete"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await deadlineService.markAsCompleted(deadline.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Marked as completed")),
                        );
                      }
                    },
                  ),
                  
                if (deadline.status == DeadlineStatus.pending)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.run_circle_outlined),
                    label: const Text("Start"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await deadlineService.markAsInProgress(deadline.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Marked as in progress")),
                        );
                      }
                    },
                  ),
                  
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditDeadlineDialog(context, deadline);
                  },
                ),
                  
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
                  label: Text(
                    "Delete",
                    style: TextStyle(color: Colors.red.shade300),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(context, deadline.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  void _showAddDeadlineDialog(BuildContext context) {
 
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    final deadlineService = Provider.of<DeadlineService>(context, listen: false);
    
 
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    

    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();
    DeadlinePriority selectedPriority = DeadlinePriority.medium;
    final tagController = TextEditingController();
    final List<String> tags = [];
    bool enableReminders = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Deadline"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Title *",
                      hintText: "Enter title",
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description (optional)",
                      hintText: "Enter description",
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
             
                  Row(
                    children: [
                      const Text("Due Date: "),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('MMM d, y').format(selectedDate),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
             
                  Row(
                    children: [
                      const Text("Due Time: "),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = time;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
       
                  const Text("Priority:"),
                  const SizedBox(height: 8),
                  SegmentedButton<DeadlinePriority>(
                    segments: DeadlinePriority.values.map((priority) => 
                      ButtonSegment<DeadlinePriority>(
                        value: priority,
                    
                        icon: Icon(
                          priority.icon,
                          color: priority.color,
                        ),
                 
                        tooltip: priority.name,
                      )
                    ).toList(),
                    selected: {selectedPriority},
                    onSelectionChanged: (Set<DeadlinePriority> selection) {
                      setState(() {
                        selectedPriority = selection.first;
                      });
                    },
             
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
       
                  TextField(
                    controller: tagController,
                    decoration: InputDecoration(
                      labelText: "Tags (optional)",
                      hintText: "Enter tag and press add",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final tag = tagController.text.trim();
                          if (tag.isNotEmpty && !tags.contains(tag)) {
                            setState(() {
                              tags.add(tag);
                              tagController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      final tag = value.trim();
                      if (tag.isNotEmpty && !tags.contains(tag)) {
                        setState(() {
                          tags.add(tag);
                          tagController.clear();
                        });
                      }
                    },
                  ),
                  
           
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: tags.map((tag) => 
                        Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              tags.remove(tag);
                            });
                          },
                        )
                      ).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
           
                  Row(
                    children: [
                      const Text("Enable Reminders"),
                      const Spacer(),
                      Switch(
                        value: enableReminders,
                        onChanged: (value) {
                          setState(() {
                            enableReminders = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Title is required")),
                    );
                    return;
                  }
                  
          
                  final dueDate = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  
      
                  final deadline = Deadline(
                    id: '', 
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim().isEmpty 
                        ? null 
                        : descriptionController.text.trim(),
                    dueDate: dueDate,
                    priority: selectedPriority,
                    status: DeadlineStatus.pending,
                    tags: tags,
                    userId: userId,
                    createdAt: DateTime.now(),
                    hasReminder: enableReminders,
                  );
                  
              
                  deadlineService.addDeadline(deadline);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Deadline added")),
                  );
                },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }


  void _showEditDeadlineDialog(BuildContext context, Deadline deadline) {
    final deadlineService = Provider.of<DeadlineService>(context, listen: false);
    
  
    final titleController = TextEditingController(text: deadline.title);
    final descriptionController = TextEditingController(text: deadline.description ?? '');
    
  
    DateTime selectedDate = deadline.dueDate;
    TimeOfDay selectedTime = TimeOfDay(
      hour: deadline.dueDate.hour,
      minute: deadline.dueDate.minute,
    );
    DeadlinePriority selectedPriority = deadline.priority;
    final tagController = TextEditingController();
    final List<String> tags = List.from(deadline.tags);
    bool enableReminders = deadline.hasReminder;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Edit Deadline"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Title *",
                      hintText: "Enter title",
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description (optional)",
                      hintText: "Enter description",
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                 
                  Row(
                    children: [
                      const Text("Due Date: "),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            DateFormat('MMM d, y').format(selectedDate),
                          ),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)), 
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                 
                  Row(
                    children: [
                      const Text("Due Time: "),
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime.format(context)),
                          onPressed: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setState(() {
                                selectedTime = time;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                 
                  const Text("Priority:"),
                  const SizedBox(height: 8),
                  SegmentedButton<DeadlinePriority>(
                    segments: DeadlinePriority.values.map((priority) => 
                      ButtonSegment<DeadlinePriority>(
                        value: priority,
                        
                        icon: Icon(
                          priority.icon,
                          color: priority.color,
                        ),
                        
                        tooltip: priority.name,
                      )
                    ).toList(),
                    selected: {selectedPriority},
                    onSelectionChanged: (Set<DeadlinePriority> selection) {
                      setState(() {
                        selectedPriority = selection.first;
                      });
                    },
                    
                    style: ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                 
                  TextField(
                    controller: tagController,
                    decoration: InputDecoration(
                      labelText: "Tags (optional)",
                      hintText: "Enter tag and press add",
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final tag = tagController.text.trim();
                          if (tag.isNotEmpty && !tags.contains(tag)) {
                            setState(() {
                              tags.add(tag);
                              tagController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      final tag = value.trim();
                      if (tag.isNotEmpty && !tags.contains(tag)) {
                        setState(() {
                          tags.add(tag);
                          tagController.clear();
                        });
                      }
                    },
                  ),
                  
         
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: tags.map((tag) => 
                        Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              tags.remove(tag);
                            });
                          },
                        )
                      ).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                 
                  Row(
                    children: [
                      const Text("Enable Reminders"),
                      const Spacer(),
                      Switch(
                        value: enableReminders,
                        onChanged: (value) {
                          setState(() {
                            enableReminders = value;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Title is required")),
                    );
                    return;
                  }
                  
                
                  final dueDate = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    selectedTime.hour,
                    selectedTime.minute,
                  );
                  
              
                  final updatedDeadline = deadline.copyWith(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim().isEmpty 
                        ? null 
                        : descriptionController.text.trim(),
                    dueDate: dueDate,
                    priority: selectedPriority,
                    tags: tags,
                    hasReminder: enableReminders,
                  
                    reminderTimes: [],
                  );
                  
              
                  deadlineService.updateDeadline(updatedDeadline);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Deadline updated")),
                  );
                },
                child: const Text("Update"),
              ),
            ],
          );
        },
      ),
    );
  }

 
  void _showDeleteConfirmation(BuildContext context, String id) {
    final deadlineService = Provider.of<DeadlineService>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Deadline"),
        content: const Text(
          "Are you sure you want to delete this deadline? This action cannot be undone."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              deadlineService.deleteDeadline(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Deadline deleted")),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
