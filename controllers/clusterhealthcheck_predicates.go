/*
Copyright 2023. projectsveltos.io. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controllers

import (
	"reflect"

	"github.com/go-logr/logr"
	clusterv1 "sigs.k8s.io/cluster-api/api/v1beta1"
	"sigs.k8s.io/controller-runtime/pkg/event"
	"sigs.k8s.io/controller-runtime/pkg/predicate"

	libsveltosv1alpha1 "github.com/projectsveltos/libsveltos/api/v1alpha1"
	logs "github.com/projectsveltos/libsveltos/lib/logsettings"
	configv1alpha1 "github.com/projectsveltos/sveltos-manager/api/v1alpha1"
)

// ClusterPredicates predicates for v1Cluster. ClusterHealthCheckReconciler watches v1Cluster events
// and react to those by reconciling itself based on following predicates
func ClusterPredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newCluster := e.ObjectNew.(*clusterv1.Cluster)
			oldCluster := e.ObjectOld.(*clusterv1.Cluster)
			log := logger.WithValues("predicate", "updateEvent",
				"namespace", newCluster.Namespace,
				"cluster", newCluster.Name,
			)

			if oldCluster == nil {
				log.V(logs.LogVerbose).Info("Old Cluster is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if Cluster.Spec.Paused has changed from true to false
			if oldCluster.Spec.Paused && !newCluster.Spec.Paused {
				log.V(logs.LogVerbose).Info(
					"Cluster was unpaused. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			if !reflect.DeepEqual(oldCluster.Labels, newCluster.Labels) {
				log.V(logs.LogVerbose).Info(
					"Cluster labels changed. Will attempt to reconcile associated ClusterHealthChecks.",
				)
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			cluster := e.Object.(*clusterv1.Cluster)
			log := logger.WithValues("predicate", "createEvent",
				"namespace", cluster.Namespace,
				"cluster", cluster.Name,
			)

			// Only need to trigger a reconcile if the Cluster.Spec.Paused is false
			if !cluster.Spec.Paused {
				log.V(logs.LogVerbose).Info(
					"Cluster is not paused.  Will attempt to reconcile associated ClusterHealthChecks.",
				)
				return true
			}
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"namespace", e.Object.GetNamespace(),
				"cluster", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Cluster deleted.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"namespace", e.Object.GetNamespace(),
				"cluster", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}

// MachinePredicates predicates for v1Machine. ClusterHealthCheckReconciler watches v1Machine events
// and react to those by reconciling itself based on following predicates
func MachinePredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newMachine := e.ObjectNew.(*clusterv1.Machine)
			oldMachine := e.ObjectOld.(*clusterv1.Machine)
			log := logger.WithValues("predicate", "updateEvent",
				"namespace", newMachine.Namespace,
				"machine", newMachine.Name,
			)

			if newMachine.Status.GetTypedPhase() != clusterv1.MachinePhaseRunning {
				return false
			}

			if oldMachine == nil {
				log.V(logs.LogVerbose).Info("Old Machine is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if Machine.Status.Phase has changed from not running to running
			if oldMachine.Status.GetTypedPhase() != newMachine.Status.GetTypedPhase() {
				log.V(logs.LogVerbose).Info(
					"Machine was not in Running Phase. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"Machine did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			machine := e.Object.(*clusterv1.Machine)
			log := logger.WithValues("predicate", "createEvent",
				"namespace", machine.Namespace,
				"machine", machine.Name,
			)

			// Only need to trigger a reconcile if the Machine.Status.Phase is Running
			if machine.Status.GetTypedPhase() == clusterv1.MachinePhaseRunning {
				return true
			}

			log.V(logs.LogVerbose).Info(
				"Machine did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"namespace", e.Object.GetNamespace(),
				"machine", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Machine did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"namespace", e.Object.GetNamespace(),
				"machine", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Machine did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}

// SveltosClusterPredicates predicates for sveltos Cluster. ClusterHealthCheckReconciler watches sveltos Cluster events
// and react to those by reconciling itself based on following predicates
func SveltosClusterPredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newCluster := e.ObjectNew.(*libsveltosv1alpha1.SveltosCluster)
			oldCluster := e.ObjectOld.(*libsveltosv1alpha1.SveltosCluster)
			log := logger.WithValues("predicate", "updateEvent",
				"namespace", newCluster.Namespace,
				"cluster", newCluster.Name,
			)

			if oldCluster == nil {
				log.V(logs.LogVerbose).Info("Old Cluster is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if Cluster.Spec.Paused has changed from true to false
			if oldCluster.Spec.Paused && !newCluster.Spec.Paused {
				log.V(logs.LogVerbose).Info(
					"Cluster was unpaused. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			if !oldCluster.Status.Ready && newCluster.Status.Ready {
				log.V(logs.LogVerbose).Info(
					"Cluster was not ready. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			if !reflect.DeepEqual(oldCluster.Labels, newCluster.Labels) {
				log.V(logs.LogVerbose).Info(
					"Cluster labels changed. Will attempt to reconcile associated ClusterHealthChecks.",
				)
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			cluster := e.Object.(*libsveltosv1alpha1.SveltosCluster)
			log := logger.WithValues("predicate", "createEvent",
				"namespace", cluster.Namespace,
				"cluster", cluster.Name,
			)

			// Only need to trigger a reconcile if the Cluster.Spec.Paused is false
			if !cluster.Spec.Paused {
				log.V(logs.LogVerbose).Info(
					"Cluster is not paused.  Will attempt to reconcile associated ClusterHealthChecks.",
				)
				return true
			}
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"namespace", e.Object.GetNamespace(),
				"cluster", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Cluster deleted.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"namespace", e.Object.GetNamespace(),
				"cluster", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"Cluster did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}

// ClusterSummaryPredicates predicates for clustersummary. ClusterHealthCheckReconciler watches sveltos ClusterSummary
// events and react to those by reconciling itself based on following predicates
func ClusterSummaryPredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newClusterSummary := e.ObjectNew.(*configv1alpha1.ClusterSummary)
			oldClusterSummary := e.ObjectOld.(*configv1alpha1.ClusterSummary)
			log := logger.WithValues("predicate", "updateEvent",
				"namespace", newClusterSummary.Namespace,
				"clustersummary", newClusterSummary.Name,
			)

			if oldClusterSummary == nil {
				log.V(logs.LogVerbose).Info("Old ClusterSummary is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if ClusterSummary Status has changed
			if !reflect.DeepEqual(oldClusterSummary.Status.FeatureSummaries, newClusterSummary.Status.FeatureSummaries) {
				log.V(logs.LogVerbose).Info(
					"ClusterSummary Status.FeatureSummaries changed. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"ClusterSummary did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			log := logger.WithValues("predicate", "createEvent",
				"namespace", e.Object.GetNamespace(),
				"clustersummary", e.Object.GetName(),
			)

			log.V(logs.LogVerbose).Info(
				"ClusterSummary did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"namespace", e.Object.GetNamespace(),
				"clustersummary", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"ClusterSummary deleted.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"namespace", e.Object.GetNamespace(),
				"clustersummary", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"ClusterSummary did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}

// HealthCheckReportPredicates predicates for HealthCheckReport. ClusterHealthCheckReconciler watches sveltos
// HealthCheckReport events and react to those by reconciling itself based on following predicates
func HealthCheckReportPredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newHCR := e.ObjectNew.(*libsveltosv1alpha1.HealthCheckReport)
			oldHCR := e.ObjectOld.(*libsveltosv1alpha1.HealthCheckReport)
			log := logger.WithValues("predicate", "updateEvent",
				"namespace", newHCR.Namespace,
				"healthCheckReport", newHCR.Name,
			)

			if oldHCR == nil {
				log.V(logs.LogVerbose).Info("Old HealthCheckReport is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if HealthCheckReport Spec has changed
			if !reflect.DeepEqual(oldHCR.Spec, newHCR.Spec) {
				log.V(logs.LogVerbose).Info(
					"HealthCheckReport changed. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"HealthCheckReport did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			log := logger.WithValues("predicate", "createEvent",
				"namespace", e.Object.GetNamespace(),
				"healthCheckReport", e.Object.GetName(),
			)

			log.V(logs.LogVerbose).Info(
				"HealthCheckReport did match expected conditions.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"namespace", e.Object.GetNamespace(),
				"healthCheckReport", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"HealthCheckReport deleted.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"namespace", e.Object.GetNamespace(),
				"healthCheckReport", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"HealthCheckReport did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}

// HealthCheckPredicates predicates for HealthCheck. ClusterHealthCheckReconciler watches sveltos
// HealthCheck events and react to those by reconciling itself based on following predicates
func HealthCheckPredicates(logger logr.Logger) predicate.Funcs {
	return predicate.Funcs{
		UpdateFunc: func(e event.UpdateEvent) bool {
			newHC := e.ObjectNew.(*libsveltosv1alpha1.HealthCheck)
			oldHC := e.ObjectOld.(*libsveltosv1alpha1.HealthCheck)
			log := logger.WithValues("predicate", "updateEvent",
				"healthCheck", newHC.Name,
			)

			if oldHC == nil {
				log.V(logs.LogVerbose).Info("Old HealthCheck is nil. Reconcile ClusterHealthCheck")
				return true
			}

			// return true if HealthCheck Spec has changed
			if !reflect.DeepEqual(oldHC.Spec, newHC.Spec) {
				log.V(logs.LogVerbose).Info(
					"HealthCheck changed. Will attempt to reconcile associated ClusterHealthChecks.")
				return true
			}

			// otherwise, return false
			log.V(logs.LogVerbose).Info(
				"HealthCheck did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
		CreateFunc: func(e event.CreateEvent) bool {
			log := logger.WithValues("predicate", "createEvent",
				"healthCheck", e.Object.GetName(),
			)

			log.V(logs.LogVerbose).Info(
				"HealthCheck did match expected conditions.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		DeleteFunc: func(e event.DeleteEvent) bool {
			log := logger.WithValues("predicate", "deleteEvent",
				"healthCheck", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"HealthCheck deleted.  Will attempt to reconcile associated ClusterHealthChecks.")
			return true
		},
		GenericFunc: func(e event.GenericEvent) bool {
			log := logger.WithValues("predicate", "genericEvent",
				"healthCheck", e.Object.GetName(),
			)
			log.V(logs.LogVerbose).Info(
				"HealthCheck did not match expected conditions.  Will not attempt to reconcile associated ClusterHealthChecks.")
			return false
		},
	}
}
