package v1alpha1

import (
	toolchainv1alpha1 "github.com/codeready-toolchain/api/pkg/apis/toolchain/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// TektonInstallationSpec defines the desired state of TektonInstallation
// +k8s:openapi-gen=true
type TektonInstallationSpec struct {
}

// TektonInstallationStatus defines the observed state of TektonInstallation
// +k8s:openapi-gen=true
type TektonInstallationStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "operator-sdk generate k8s" to regenerate code after modifying this file
	// Add custom validation using kubebuilder tags: https://book-v1.book.kubebuilder.io/beyond_basics/generating_crd.html

	// Conditions is an array of current TektonInstallation conditions
	// Supported condition types:
	// TektonReady
	// +optional
	// +patchMergeKey=type
	// +patchStrategy=merge
	// +listType
	Conditions []toolchainv1alpha1.Condition `json:"conditions,omitempty" patchStrategy:"merge" patchMergeKey:"type"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// TektonInstallation is the Schema for the tektoninstallations API
// +k8s:openapi-gen=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=tektoninstallations,scope=Cluster
// +kubebuilder:printcolumn:name="Ready",type="string",JSONPath=".status.conditions[?(@.type==\"TektonReady\")].status"
// +kubebuilder:printcolumn:name="Reason",type="string",JSONPath=".status.conditions[?(@.type==\"TektonReady\")].reason"
type TektonInstallation struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   TektonInstallationSpec   `json:"spec,omitempty"`
	Status TektonInstallationStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// TektonInstallationList contains a list of TektonInstallation
type TektonInstallationList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []TektonInstallation `json:"items"`
}

func init() {
	SchemeBuilder.Register(&TektonInstallation{}, &TektonInstallationList{})
}
